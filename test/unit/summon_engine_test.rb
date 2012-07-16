require 'test_helper'

require 'cgi'
require 'uri'

#
# To run queries live (without recorded VCR), you must have ENV variables
# set: SUMMON_ACCESS_ID and SUMMON_SECRET_KEY


class SummonEngineTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  @@access_id   = (ENV['SUMMON_ACCESS_ID']  || "DUMMY_ACCESS_ID")
  @@secret_key  = (ENV['SUMMON_SECRET_KEY'] || "DUMMY_SECRET_KEY")
  
  VCR.configure do |c|
    c.filter_sensitive_data("DUMMY_ACCESS_ID", :summon)  { @@access_id }
    c.filter_sensitive_data("DUMMY_SECRET_KEY", :summon) { @@secret_key }
  end
  
  def setup
    @engine = BentoSearch::SummonEngine.new('access_id' => @@access_id, 
      'secret_key' => @@secret_key)
  end
  
  def test_request_construction 
    uri, headers = @engine.construct_request(:query => "elephant's")
    
    
    assert_present headers
    assert_present headers["Content-Type"]
    assert_present headers["Accept"]
    assert_present headers["x-summon-date"]
    assert_present headers["Authorization"]
    
    
    assert_present uri
    query_params = CGI.parse( URI.parse(uri).query )
    assert_present query_params["s.q"]        
  end
  
  def test_summon_escape
    uri, headers = @engine.construct_request(:query=> "Foo: A) \\Bar")
    
    query_params = CGI.parse( URI.parse(uri).query )
    
    assert_present (query = query_params["s.q"].first)
    
    # double backslashes are escaping for ruby string literal,
    # it's actually only a single backslash in output. 
    assert_equal "Foo\\: A\\) \\\\Bar", query
  end
  
  def test_sort_construction
    uri, headers = @engine.construct_request(:query => "elephants", :sort => "date_desc")
    
    query_params = CGI.parse( URI.parse(uri).query )
    
    assert_present (sort = query_params["s.sort"].first )
    
    assert_equal("PublicationDate:desc", sort)
    
  end
  
  def test_fielded_search_construction
    uri, headers = @engine.construct_request(:query => "eleph)ants", :search_field => "SomeField")
    
    query_params = CGI.parse( URI.parse(uri).query )

    assert_equal "SomeField:(eleph\\\)ants)", query_params["s.q"].first
  end
  
  def test_authenticated_user_construction 
    uri, headers = @engine.construct_request(:query => "elephants", :auth => true)
    
    query_params = CGI.parse( URI.parse(uri).query )
    
    assert_present query_params['s.role']
    assert_equal "authenticated", query_params['s.role'].first   
  end        
  
  def test_construct_fixed_param_config
    engine = BentoSearch::SummonEngine.new('access_id' => @@access_id, 
      'secret_key' => @@secret_key,
      'fixed_params' => {
        "s.fvf" => ["ContentType,Newspaper Article,true", "ContentType,Book,true"],
        "s.role" => "authenticated"
      })
    
    uri, headers = engine.construct_request(:query => "elephants")
    
    query_params = CGI.parse( URI.parse(uri).query )
    
    assert_include query_params["s.fvf"], "ContentType,Newspaper Article,true"
    assert_include query_params["s.fvf"], "ContentType,Book,true"
    assert_include query_params["s.role"], "authenticated"
    
  end
  
  test_with_cassette("bad auth", :summon) do
    engine = BentoSearch::SummonEngine.new('access_id' => "bad_access_id", :secret_key => 'bad_secret_key')
    
    results = engine.search("elephants")
    
    assert results.failed?, "should return #failed?"   
  end
    
  
  def test_search
    pending "need sersol to fix account"
    VCR.turned_off do 
      WebMock.allow_net_connect!
      
      results = @engine.search("elephants")
      
      assert ! results.failed?
      
      assert_present results
      
      assert_present results.total_items
      assert_not_equal 0, results.total_items
      
      
      WebMock.disable_net_connect!
    end
  end
  
end
