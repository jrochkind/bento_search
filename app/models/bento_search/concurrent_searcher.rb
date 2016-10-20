# EXPERIMENTAL replacement for Celluloid-based MultiSearcher,
# with ruby-concurrent base instead. Need docs about Rails dev-mode
# auto-reloading and concurrency, argh.
begin
  require 'concurrent'

  class BentoSearch::ConcurrentSearcher
    def initialize(*engine_ids)
      @engines = []
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
      @futures = @engines.collect do |engine|
        Concurrent::Future.execute { engine.search(*search_args) }
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
        pairs = @futures.collect { |future| [future.value!.engine_id, future.value!] }
        Hash[ pairs ].freeze
      end
    end

  end
rescue LoadError
  # you can use bento_search without celluloid, just not
  # this class.
  $stderr.puts "Tried but could not load BentoSearch::ConcurrentSearcher, concurrent-ruby not available!"
end
