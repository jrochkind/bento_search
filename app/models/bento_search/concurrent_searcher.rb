begin
  require 'concurrent'

  # Concurrently runs multiple searches in separate threads. Since a search
  # generally spends most of it's time waiting on foreign API, this is
  # useful to significantly reduce total latency of running multiple searches,
  # even in MRI.
  #
  # Uses [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby),
  # already a dependency of Rails 5.x. To use with Rails previous to 5.x,
  # just add concurrent-ruby to your `Gemfile`:
  #
  #     gem 'concurrent-ruby', '~> 1.0'
  #
  # # Usage
  #
  # initialize with id's of registered engines:
  #
  #     searcher = BentoBox::ConcurrentSearcher.new(:gbs, :scopus)
  #
  # start the concurrent searches, params same as engine.search
  #
  #     searcher.search( query_params )
  #
  # retrieve results, blocking until all are completed:
  #
  #     results = searcher.results
  #
  # returns a Hash keyed by engine id, values BentoSearch::Results objects.
  #
  #     results # => { "gbs" => <BentoSearch::Results ...>, "scopus" =>  <BentoSearch::Results ...>}
  #
  # Calling results more than once will just return the initial results again
  # (cached), it won't run a search again.
  #
  # ## Dev-mode autoloading and concurrency
  #
  # In Rails previous to Rails5, you may have to set config.cache_classes=true
  # even in development to avoid problems. In Rails 5.x, we take advantage of
  # new api that should allow concurrency-safe autoloading. But if you run into
  # any weird problems (such as a deadlock), `cache_classes = true` and
  # `eager_load = true` should eliminate them, at the cost of dev-mode
  # auto-reloading.
  #
  #
  # TODO: have a method that returns Futures instead of only supplying the blocking
  # results method? Several tricks, including making sure to properly terminate actors.
  class BentoSearch::ConcurrentSearcher
    def initialize(*engine_ids)
      auto_rescued_exceptions = [StandardError]

      @engines = []
      engine_ids.each do |id|
        add_engine( BentoSearch.get_engine(id).tap { |e| e.auto_rescued_exceptions = auto_rescued_exceptions + e.auto_rescued_exceptions })
      end
      @extra_auto_rescue_exceptions = [StandardError]
    end

    # Adds an instantiated engine directly, rather than by id from global
    # registry.
    def add_engine(engine)
      unless engine.configuration.id.present?
        raise ArgumentError.new("ConcurrentSearcher engines need `configuration.id`, this one didn't have one: #{engine}")
      end
      @engines << engine
    end

    # Starts all searches, returns self so you can chain method calls if you like.
    def search(*search_args)
      search_args.freeze
      @futures = @engines.collect do |engine|
        Concurrent::Future.execute { rails_future_wrap { engine.search(*search_args) } }
      end
      return self
    end

    # Have you called #search yet? You can only call #results if you have.
    # Will stay true forever, it doesn't tell you if the search is done or not.
    def search_started?
      !! @futures
    end

    # Call after #search. Blocks until each included engine is finished
    # then returns a Hash keyed by engine registered id, value is a
    # BentoSearch::Results object.
    #
    # If called multiple times, returns the same results each time, does
    # not re-run searches.
    #
    # It is an error to invoke without having previously called #search
    def results
      unless search_started?
        raise ArgumentError, "Can't call ConcurrentSearcher#results before you have executed a #search"
      end

      @results ||= begin
        pairs = rails_wait_wrap do
          @futures.collect { |future| [future.value!.engine_id, future.value!] }
        end
        Hash[ pairs ].freeze
      end
    end

    protected

    # In Rails5, future body's need to be wrapped in an executor,
    # to handle auto-loading right in dev-mode, among other things.
    # Rails docs coming, see https://github.com/rails/rails/issues/26847
    @@rails_has_executor = Rails.application.respond_to?(:executor)
    def rails_future_wrap
      if @@rails_has_executor
        Rails.application.executor.wrap { yield }
      else
        yield
      end
    end

    # In Rails5, if we are collecting from within an action method
    # (ie the 'request loop'), as we usually will be, we need to
    # give up the autoload lock. Rails docs coming, see https://github.com/rails/rails/issues/26847
    @@rails_needs_interlock_permit = ActiveSupport::Dependencies.respond_to?(:interlock) &&
      !(Rails.application.config.eager_load && Rails.application.config.cache_classes)
    def rails_wait_wrap
      if @@rails_needs_interlock_permit
        ActiveSupport::Dependencies.interlock.permit_concurrent_loads { yield }
      else
        yield
      end
    end

  end
rescue LoadError
  # you can use bento_search without celluloid, just not
  # this class.
  $stderr.puts "Tried but could not load BentoSearch::ConcurrentSearcher, concurrent-ruby not available!"
end
