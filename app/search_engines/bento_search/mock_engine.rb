# A fake engine that simply makes up it's results, used in testing. 
#
# Used in BentoSearch's own automated tests, but exposed publically because
# can be useful to use in your tests for software that uses BentoSearch too. 
#
# The nature of the fake results can be controlled by config variables:
#
# [:total_items]  total_items to report
# [:sort_definitions] hash for #sort_definitions
# [:link]             link to give to each item in results
# [:error]            set to an error value hash and results returned
#                     will all be failed? with that error hash. 
class BentoSearch::MockEngine
    include BentoSearch::SearchEngine
    
    def search_implementation(args)
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
    
    def self.default_configuration
      { :num_results => nil,
        :total_items => 1000, 
        :link => "http://example.org",
        :error => nil}
    end
    
    def sort_definitions
      configuration.sort_definitions || {}
    end
    
end
