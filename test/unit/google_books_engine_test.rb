require 'test_helper'

class GoogleBooksEngineTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  def setup
    conf = Confstruct::Configuration.new :api_key => "dummy"
    @engine = BentoSearch::GoogleBooksEngine.new(  conf   )
    # tell it not to send our bad API key
    @engine.suppress_key = true
  end

  
  
  test_with_cassette("search", :gbs) do
    results = @engine.search("cancer")
    
    assert_kind_of BentoSearch::Results, results
    
    assert ! results.failed?
    
    assert_not_nil results.total_items
    assert_equal 0, results.start
    assert_equal 10, results.per_page
    
    assert_not_empty results
    
    first = results.first
    
    assert_kind_of BentoSearch::ResultItem, first
    
    assert_not_empty first.title
    assert_not_empty first.link
    assert_not_empty first.format
    assert_not_nil first.year
    assert_not_empty first.abstract
    assert first.abstract.html_safe?
  end
  
  test_with_cassette("pagination", :gbs) do
    results = @engine.search("cancer", :per_page => 20, :start => 40)
    
    assert ! results.failed?
    
    assert_equal 20, results.length
    
    assert_equal 20, results.per_page
    assert_equal 20, results.size
    assert_equal 40, results.start
  end

    
  
  test_with_cassette("error condition", :gbs) do    
      # Intentionally send with bad google api key to trigger error
      @engine.suppress_key = false
      begin    
        results = @engine.search("cancer")      
        
        assert results.failed?
        assert_not_nil results.error
        assert_not_nil results.error[:status]
        assert_not_nil results.error[:error_info]      
      ensure
        @engine.suppress_key = true
      end
  end
  
  

  
  def test_fielded_search    
    # Have to use protected methods to get at what we want to test. 
    # Is there a better way to factor this for testing?
    norm_args = @engine.send(:parse_search_arguments, 'cancer "by radiation"', :search_field => :intitle)
    url = @engine.send(:args_to_search_url, norm_args)
    
    query_params = CGI.parse( URI.parse(url).query )
    
    assert_match /^|\sintitle\:cancer\s|$/, query_params["q"].first
    assert_match /^|\sintitle\:"by radiation"\s|$/, query_params["q"].first
  end
    
  
end
