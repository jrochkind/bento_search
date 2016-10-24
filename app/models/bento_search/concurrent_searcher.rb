# EXPERIMENTAL replacement for Celluloid-based MultiSearcher,
# with ruby-concurrent base instead. Need docs about Rails dev-mode
# auto-reloading and concurrency, argh.
begin
  require 'concurrent'

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

    # Call after #start. Blocks until each included engine is finished
    # then returns a Hash keyed by engine registered id, value is a
    # BentoSearch::Results object.
    #
    # If called multiple times, returns the same results each time, does
    # not re-run searches.
    def results
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
