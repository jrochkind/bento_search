begin
  require 'celluloid'

  # Based on Celluloid, concurrently runs multiple searches in
  # seperate threads. You must include 'celluloid' gem dependency
  # into your local app to use this class. Requires celluloid 0.12.0
  # or above (for new preferred async syntax).
  #
  # Warning, if you don't have celluloid in your app, this class simply
  # won't load. TODO: We should put this file in a different directory
  # so it's never auto-loaded, and requires a "require 'bento_search/multi_searcher'",
  # such that it will raise without celluloid only then, and we don't need this
  # rescue LoadError stuff.
  #
  # I am not an expert at use of Celluloid, it's possible there's a better
  # way to do this all, but seems to work.
  #
  # ## Usage
  #
  # initialize with id's of registered engines:
  #     searcher = BentoBox::MultiSearcher.new(:gbs, :scopus)
  #
  # start the concurrent searches, params same as engine.search
  #     searcher.search( query_params )
  #
  # retrieve results, blocking until each is completed:
  #     searcher.results
  #
  # returns a Hash keyed by engine id, values BentoSearch::Results objects.
  #
  # Can only call #results once per #start, after that it'll return empty hash.
  # (should we make it actually raise instead?). .
  #
  # important to call results at some point after calling start, in order
  # to make sure Celluloid::Actors are properly terminated to avoid
  # resource leakage. May want to do it in an ensure block.
  #
  # Note that celluloid uses multi-threading in such a way that you
  # may have to set config.cache_classes=true even in development
  # to avoid problems. Rails class reloading is not thread-safe.
  #
  #
  # TODO: have a method that returns Futures instead of only supplying the blocking
  # results method? Several tricks, including making sure to properly terminate actors.
  class BentoSearch::MultiSearcher

    def initialize(*engine_ids)
      ActiveSupport::Deprecation.warn('BentoSearch::MultiSearcher is deprecated and will be removed in bento_search 2.0. Please use BentoSearch::ConcurrentSearcher instead.', caller.slice(1..-1))

      @engines = []
      @actors = []
      engine_ids.each do |id|
        add_engine( BentoSearch.get_engine id )
      end
    end

    # Adds an instantiated engine directly, rather than by id from global
    # registry.
    def add_engine(engine)
      @engines << engine
    end

    # Starts all searches, returns self so you can chain method calls if you like.
    def search(*search_args)
      @engines.each do |engine|
        a = Actor.new(engine)
        @actors << a
        a.async.start *search_args
      end
      return self
    end
    alias_method :start, :search # backwards compat

    # Call after #start. Blocks until each included engine is finished
    # then returns a Hash keyed by engine registered id, value is a
    # BentoSearch::Results object.
    #
    # Can only call _once_ per invocation of #start, after that it'll return
    # an empty hash.
    def results
      results = {}

      # we use #delete_if to get an iterator that deletes
      # each item after iteration.
      @actors.delete_if do |actor|
        result_key = (actor.engine.configuration.id || actor.engine.class.name)
        results[result_key] = actor.results
        actor.terminate

        true
      end

      return results
    end


    class Actor
      include Celluloid

      attr_accessor :engine

      def initialize(a_engine)
        self.engine = a_engine
      end

      # call as .async.start, to invoke async.
      def start(*search_args)
        begin
          @results = self.engine.search(*search_args)
        rescue StandardError => e
          Rails.logger.error("\nBentoSearch:MultiSearcher caught exception: #{e}\n#{e.backtrace.join("   \n")}")
          # Make a fake results with caught exception.
          @results = BentoSearch::Results.new
          self.engine.fill_in_search_metadata_for(@results, self.engine.normalized_search_arguments(search_args))

          @results.error ||= {}
          @results.error["exception"] = e
        end
      end

      def results
        @results
      end

    end
  end

rescue LoadError
  # you can use bento_search without celluloid, just not
  # this class.
end

