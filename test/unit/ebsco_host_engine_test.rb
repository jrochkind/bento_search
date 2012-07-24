require 'cgi'
require 'uri'

class EbscoHostEngineTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  def setup
    @engine = BentoSearch::EbscoHostEngine.new( 
      :profile_id => "foo",
      :profile_password => "foo",
      :databases => %w{ab1, ab2, ab3}
      )
  end
  
  
  def test_url_construction
    url = @engine.query_url(:query => "cancer", :start => 10, :per_page => 5)
    
    assert_present url
    
    query_params = CGI.parse( URI.parse(url).query )

    assert_equal [@engine.configuration.profile_id], query_params["prof"]
    assert_equal [@engine.configuration.profile_password], query_params["pwd"]
    
    assert_equal ["cancer"], query_params["query"]
    
    assert_equal ["5"], query_params["numrec"]
    assert_equal ["11"], query_params["startrec"]
    
    # default sort relevance
    assert_equal ["relevance"], query_params["sort"]
    
    @engine.configuration.databases.each do |db|
      assert_include query_params["db"], db
    end    
  end
  
  def test_date_sort_construction
    url = @engine.query_url(:query => "cancer", :sort => "date_desc")
    
    query_params = CGI.parse( URI.parse(url).query )
    
    assert_equal ["date"], query_params["sort"]
  end
  
end
