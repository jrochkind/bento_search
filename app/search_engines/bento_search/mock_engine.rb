# A fake engine that simply makes up it's results, used in testing. 
#
# Used in BentoSearch's own automated tests, but exposed publically because
# can be useful to use in your tests for software that uses BentoSearch too. 
#
# The nature of the fake results can be controlled by config variables:
#
# [:num_results]      how many items to include in returned results (default
#                     specified per_page, or 10)
# [:total_items]  total_items to report
# [:sort_definitions] hash for #sort_definitions
# [:search_field_definitions] hash for #search_field_definitions
# [:link]             link to give to each item in results
# [:error]            set to an error value hash and results returned
#                     will all be failed? with that error hash. 
# [:raise_exception_class]  string name of exception class that the engine will raise and not catch,
#                     to be caught by BentoSearch::SearchEngine wrapper possibly. 
# [:timing]           in seconds, fill out the results as if they took
#                     this long. 
# [:supports_multi_search] true or false
class BentoSearch::MockEngine
    include BentoSearch::SearchEngine
    
    # used for testing what the engine received as args
    attr_accessor :last_args
    
    def search_implementation(args)
      self.last_args = args
      
      if configuration.raise_exception_class
        raise configuration.raise_exception_class.constantize.new("MockEngine forced raise")
      end
      
      results = BentoSearch::Results.new
      
      if configuration.error
        results.error = configuration.error
        return results
      end
      
      1.upto(configuration.num_results || args[:per_page] ) do |i|
        results << BentoSearch::ResultItem.new(:title => "Item #{i}: #{args[:query]}", :link => configuration.link)
      end
      results.total_items = configuration.total_items      
      return results
    end    
    
    def search(*args)
      results = super(*args)
      results.timing = configuration.timing if configuration.timing
      return results
    end
    
    def self.default_configuration
      { :num_results => nil,
        :total_items => 1000, 
        :link => "http://example.org",
        :error => nil,
        :timing => nil}
    end
    
    def sort_definitions
      configuration.sort_definitions.try(:to_hash).try(:stringify_keys) || {}
    end
    
    def search_field_definitions
      configuration.search_field_definitions.try(:to_hash).try(:stringify_keys) || {}
    end

    def multi_field_search?
      configuration.multi_field_search || false
    end
    
end
