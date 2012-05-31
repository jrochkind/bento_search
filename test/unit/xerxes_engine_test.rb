require 'test_helper'

require 'cgi'
require 'uri'

# If you need to re-record cassette, you need to REMOVE
# the :refresh_wait => 0 below, along with
# the :record => once in the use_cassette
class XerxesEngineTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  def setup    
    conf = Confstruct::Configuration.new( :base_url => "http://jhsearch.library.jhu.edu/",
      :databases => ["JHU04066","JHU06614"] ,
      # when we have a VCR recorded, we don't need to wait
      # if re-recording, change this key to nil. 
      :refresh_wait => 0 
      )
    @engine = BentoSearch::XerxesEngine.new( conf )
  end

  
  def test_construct_xerxes_url
    url = @engine.send(:xerxes_search_url, {:query => "skin disease"})
    
    uri = nil
    assert_nothing_raised { uri = URI.parse(url) } 
    
    assert uri.to_s.start_with?(@engine.configuration.base_url), "starts with base_url"
    
    query_hash = CGI.parse( uri.query )
    
    assert_equal ["metasearch"],  query_hash["base"]
    assert_equal ["search"],      query_hash["action"]
    #assert_equal [@engine.configuration.xerxes_context], query_hash["context"]
    assert_equal ["WRD"],         query_hash["field"]
    assert_equal ["skin disease"],query_hash["query"]
    
    @engine.configuration.databases.each do |db|    
      assert query_hash["database"].include?(   db   )
    end        
  end
  
  test_with_cassette("live search", :xerxes, :record => :none) do
    results = @engine.search("skin disease")
    
    assert results.length > 0, "returns results"
    
    record = results.first
    
    assert_present record.title
    assert_present record.format
    assert_present record.link
    assert_present record.volume
    assert_present record.issue
    assert_present record.start_page
    assert_present record.end_page
    assert_present record.abstract
    assert_present record.openurl_kev_co
    assert_present record.journal_title
    assert_present record.issn
    
    assert_operator record.authors.length, :>, 0
    
    assert_present record.authors.first.first
    assert_present record.authors.first.last
    
  end
  
end
