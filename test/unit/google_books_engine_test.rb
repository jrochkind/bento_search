require 'test_helper'


class GoogleBooksEngineTest < ActiveSupport::TestCase
  def setup
    conf = Confstruct::Configuration.new :api_key => "dummy"
    @engine = BentoSearch::GoogleBooksEngine.new(  conf   )
    # tell it not to send our bad API key
    @engine.suppress_key = true
  end
  
  def test_search
    results = @engine.search("cancer")
    
    assert_kind_of BentoSearch::Results, results
    
    assert_not_nil results.total_items
    
    assert_not_empty results
    
    first = results.first
    
    assert_kind_of BentoSearch::ResultItem, first
    
    assert_not_empty first.title
    assert_not_empty first.link
    assert_not_empty first.format
    assert_not_nil first.year_published
    assert_not_empty first.abstract
    assert first.abstract.html_safe?
  end
  
  def test_error_condition
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
  
end
