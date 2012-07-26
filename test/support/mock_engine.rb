class MockEngine
    include BentoSearch::SearchEngine
    
    def search_implementation(args)
      results = BentoSearch::Results.new
      1.upto(configuration.num_results) do |i|
        results << BentoSearch::ResultItem.new(:title => "Item #{i}: #{args[:query]}", :link => configuration.link)
      end
      results.total_items = configuration.total_items      
      return results
    end    
    
    def self.default_configuration
      { :num_results => 10,
        :total_items => 1000, 
        :link => "http://example.org"}
    end
    
    def sort_definitions
      configuration.sort_definitions || {}
    end
    
end
