require 'test_helper'

require 'cgi'
require 'uri'

class WorldcatSruDcEngineTest < ActiveSupport::TestCase
  extend TestWithCassette

  @@api_key = ENV["WORLDCAT_API_KEY"] || "DUMMY_API_KEY"

  
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
  
  test("smoke test") do
    VCR.turned_off do
      results = @engine.search("cancer")
      
      assert_present results
      
      assert_present results.total_items
      
      first = results.first
      
      assert_present first.title
      
    end
  end
  
end
