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
  
  test_with_cassette("simple search", :scopus) do
    response = @engine.search(:query => "cancer")
    
  end
    
  
end
