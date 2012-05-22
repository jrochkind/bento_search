require 'test_helper'

require 'cgi'
require 'uri'

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
  
  test_with_cassette("live search", :xerxes) do
    results = @engine.search("skin disease")
    
    require 'debugger'
    1+1
    
  end
  
end
