class MockEngine
    include BentoSearch::SearchEngine
    
    def search_implementation(args)
      results = BentoSearch::Results.new
      1.upto(configuration.num_results) do |i|
        results << BentoSearch::ResultItem.new(:title => "Item #{i}: #{args[:query]}", :link => configuration.link)
      end      
      return results
    end    
    
    def self.default_configuration
      {:num_results => 10, :link => "http://example.org"}
    end
    
end
