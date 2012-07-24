require 'cgi'
require 'uri'

class EbscoHostEngineTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  @@profile_id = (ENV['EBSCOHOST_PROFILE'] || 'DUMMY_PROFILE')
  @@profile_pwd = (ENV['EBSCOHOST_PWD'] || 'DUMMY_PWD')
  @@dbs_to_test = (ENV['EBSCOHOST_TEST_DBS'] || %w{a9h awn} )
  
  VCR.configure do |c|
    c.filter_sensitive_data("DUMMY_PROFILE", :ebscohost) { @@profile_id }
    c.filter_sensitive_data("DUMMY_PWD", :ebscohost) { @@profile_pwd }
  end
  
  
  def setup
    @engine = BentoSearch::EbscoHostEngine.new( 
      :profile_id => @@profile_id,
      :profile_password => @@profile_pwd,
      :databases => @@dbs_to_test
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
  
  test_with_cassette("live search smoke test", :ebscohost) do
  
    results = @engine.search(:query => "cancer")
    
    assert_present results
    assert ! results.failed?
    
    first = results.first
    
    assert_present first.title
    assert_present first.authors  
  end
  
end
