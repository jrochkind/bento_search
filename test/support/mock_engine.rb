class MockEngine
    include BentoSearch::SearchEngine
    
    def search_implementation(args)
      results = BentoSearch::Results.new
      1.upto(10) do |i|
        results << BentoSearch::ResultItem.new(:title => "Item #{i}: #{args[:query]}")
      end      
      return results
    end    
    
end
