require 'test_helper'

# Set shell env SCOPUS_KEY to your api key to test fresh http
# connections, if you can't use the ones cached by VCR. 

class ScopusEngineTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  # Filter API key out of VCR cache for tag :scopus, which we'll use
  # in this test. 
  @@api_key = (ENV["SCOPUS_KEY"] || "DUMMY_API_KEY")
  VCR.configure do |c|
    c.filter_sensitive_data("DUMMY_API_KEY", :scopus) { @@api_key }
  end
  
  def setup
    @engine = BentoSearch::ScopusEngine.new(:api_key => @@api_key)
  end
  
  
  def test_construct_search_url
    url = @engine.send(:scopus_url, :query => "one two")
    
    assert_equal "http://api.elsevier.com/content/search/index:SCOPUS?query=one+two", url
  end
  
  def test_construct_fielded_search_url
    url = @engine.send(:scopus_url, :query => "one two", :search_field => "AUTH")
    
    assert_equal "http://api.elsevier.com/content/search/index:SCOPUS?query=AUTH%28one+two%29", url
  end
  
  def test_construct_search_with_per_page
    url = @engine.send(:scopus_url, :query => "one two", :per_page => 25)
    
    assert_equal "http://api.elsevier.com/content/search/index:SCOPUS?query=one+two&count=25", url
  end
  
  
  test_with_cassette("bad api key should return error response", :scopus) do
    @engine = BentoSearch::ScopusEngine.new(:api_key => "BAD_KEY_ERROR")
    
    results = @engine.search(:query => "cancer")
    
    assert results.failed?, "response.failed? should be"  
  end
  
  test_with_cassette("simple search", :scopus) do
    results = @engine.search(:query => "cancer")
    
    assert_not_nil results.total_items, "total_items not nil"
    assert_not_nil results.start, "start not nil"
    assert_not_nil results.per_page, "per_page not nil"
    
    assert_equal BentoSearch::ScopusEngine.default_per_page, results.length
    
    sample_result = results.first
    
    assert_present sample_result.title
    assert_present sample_result.link
    assert_present sample_result.journal_title
    assert_kind_of Integer, sample_result.year
    assert_present sample_result.issn
    assert_present sample_result.volume
    assert_present sample_result.issue
    assert_present sample_result.start_page
    
    assert_present sample_result.authors    
    
    assert_present sample_result.format
    
  end
  
  test_with_cassette("fielded search", :scopus) do
    results = @engine.search(:query => "cancer", :semantic_search_field => :title)

    assert results.first.title.downcase.include?("cancer"), "Title includes query term"    
  end
  
  
    
  
end
