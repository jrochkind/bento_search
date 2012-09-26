require 'test_helper'

require 'cgi'
require 'uri'

#
#
# Using the MARCXML response is way too much work, but the XML 'DC' response
# is awfully stunted. We do what we can with it, but resulting metadata
# is weird. 
#
class WorldcatSruDcEngineTest < ActiveSupport::TestCase
  extend TestWithCassette

  @@api_key = ENV["WORLDCAT_API_KEY"] || "DUMMY_API_KEY"
  
  VCR.configure do |c|
    c.filter_sensitive_data("DUMMY_API_KEY", :worldcat_sru_dc) { @@api_key }
  end

  
  def setup
    @config = {:api_key => @@api_key}
    @engine = BentoSearch::WorldcatSruDcEngine.new(@config)
  end
  
  def test_construct_url
    query = 'cancer\'s "one two"'
    url = @engine.construct_query_url(:query => query, :per_page => 10)
    
    query_hash = CGI.parse(URI.parse(url).query)

    assert_equal [@engine.configuration.api_key],      query_hash["wskey"]
    assert_equal ['info:srw/schema/1/dc'], query_hash["recordSchema"]
    assert_equal [@engine.construct_cql_query(:query => query)],   query_hash["query"]
  end
  
  def test_construct_pagination
    url = @engine.construct_query_url(:query => "cancer", :per_page => 20, :start => 20)
    
    query_hash = CGI.parse(URI.parse(url).query)
    
    assert_equal ["20"],  query_hash["maximumRecords"]
    assert_equal ["21"],  query_hash["startRecord"]
  end
  
  def test_construct_sort
    url = @engine.construct_query_url(:query => "cancer", :sort => "date_desc")
      
    query_hash = CGI.parse(URI.parse(url).query)
    
    assert_present query_hash["sortKeys"]
  end
  
  def test_construct_fielded_search
    cql = @engine.construct_cql_query(:query => "cancer", :search_field => "srw.ti")
    
    assert_equal 'srw.ti = "cancer"', cql
  end
  
  def test_construct_servicelevel
    url = @engine.construct_query_url(:query => "cancer")    
    query_hash = CGI.parse(URI.parse(url).query)
    assert_not_include query_hash["servicelevel"], "full"
        
    url = @engine.construct_query_url(:query => "cancer auth", :auth => true)    
    query_hash = CGI.parse(URI.parse(url).query)
    assert_include query_hash["servicelevel"], "full"
    
    default_on = BentoSearch::WorldcatSruDcEngine.new(@config.merge(:auth => true))
    
    url = default_on.construct_query_url(:query => "cancer")    
    query_hash = CGI.parse(URI.parse(url).query)
    assert_include query_hash["servicelevel"], "full"
    
    url = default_on.construct_query_url(:query => "cancer", :auth => false)    
    query_hash = CGI.parse(URI.parse(url).query)
    assert_not_include query_hash["servicelevel"], "full"    
  end
  
  def test_construct_cql
    # test proper escaping and such
    cql = @engine.construct_cql_query(:query => "alpha's beta \"one two\" thr\"ee")

    components = cql.split(" AND ")
    
    assert_equal 4, components.length
    
    ["srw.kw = \"beta\"", 
     "srw.kw = \"alpha's\"", 
     "srw.kw = \"one two\"",  
     "srw.kw = \"thr\\\"ee\""].each do |clause|
      assert_include components, clause
    end        
  end
  
  test_with_cassette("smoke test", :worldcat_sru_dc) do
    results = @engine.search("anarchism")
    
    assert_present results
    
    assert_present results.total_items
    
    first = results.first
    
    assert_present first.title
    assert_present first.authors
    assert_present first.publisher
    assert_present first.oclcnum
    
    assert_present first.year
    
    assert_present first.abstract
    
    assert_present first.link
    
    assert_present first.language_code      
  end
  
  test_with_cassette("catch sru error", :worldcat_sru_dc) do
    # worldcat doesn't allow paging past 9999th record
    results = @engine.search("cancer", :start => 10000)
    
    assert results.failed?
    assert_present results.error[:info]    
  end
  
end
