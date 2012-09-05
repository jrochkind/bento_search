require 'test_helper'

require 'uri'
require 'cgi'

# To run these tests without VCR cassettes, need
# ENV GOOGLE_SITE_SEARCH_KEY and GOOGLE_SITE_SEARCH_CX
class GoogleSiteSearchTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  @@api_key = ENV["GOOGLE_SITE_SEARCH_KEY"] || "DUMMY_API_KEY"
  @@cx      = ENV["GOOGLE_SITE_SEARCH_CX"] || "DUMMY_CX"
  
  VCR.configure do |c|
    c.filter_sensitive_data("DUMMY_API_KEY", :google_site) { @@api_key }
    c.filter_sensitive_data("DUMMY_CX", :google_site) { @@cx }
  end
  
  setup do
    @config = {:api_key => @@api_key, :cx => @@cx}
    @engine = BentoSearch::GoogleSiteSearchEngine.new(@config)
  end
  
  test("basic query construction") do
    url = @engine.send(:construct_query, {:query => "hours policies"})
    
    query_params = CGI.parse( URI.parse(url).query )    

    assert_equal ["hours policies"], query_params["q"]
  end
  
  test("pagination construction") do    
    url = @engine.send(:construct_query, {:query => "books", :per_page => 5, :start => 10})
    
    query_params = CGI.parse( URI.parse(url).query )
    
    assert_equal ["5"], query_params["num"]
    assert_equal ["11"], query_params["start"]
  end
  
  test("silently refuses to paginate too far") do
    # google won't let you paginate past ~10 pages, (101 - num). We silently
    # refuse
    
    url = @engine.send(:construct_query, {:query => "books", :start => 110})
    
    query_params = CGI.parse( URI.parse(url).query )
    
    assert_equal ["91"], query_params["start"]
  end
  
  test_with_cassette("pagination object is correct for actual page when you ask for too far", :google_site) do
    results = @engine.search("books", :start => 1000)
    
    pagination = results.pagination
    
    assert_equal 10, pagination.current_page
    assert_equal 91, pagination.start_record    
  end
  
  test("sort query construction") do
    url = @engine.send(:construct_query, {:query => "books", :sort => "date_desc"})
    
    query_params = CGI.parse( URI.parse(url).query )
    
    assert_equal ["date"], query_params["sort"]
  end
  
  test_with_cassette("basic smoke test", :google_site) do    
    results = @engine.search("books")
    
    assert_present results
    assert_present results.total_items
    assert_kind_of Fixnum, results.total_items
    
    first = results.first
    
    assert_present first.title
    assert_present first.link
    assert_present first.abstract
    assert_present first.journal_title # used as source_title for display url    
  end
  
  test_with_cassette("with highlighting", :google_site) do
    engine = BentoSearch::GoogleSiteSearchEngine.new(@config.merge(:highlighting => true))
    
    results = engine.search("books")
    
    first = results.first

    assert first.title.html_safe?    
    assert first.abstract.html_safe?
    assert first.journal_title.html_safe?
    
    assert first.published_in.html_safe?
  end
  
  test_with_cassette("without highlighting", :google_site) do
    engine = BentoSearch::GoogleSiteSearchEngine.new(@config.merge(:highlighting => false))
    
    results = engine.search("books")
    
    first = results.first
    
    assert ! first.title.html_safe?    
    assert ! first.abstract.html_safe?
    assert ! first.journal_title.html_safe?        
  end
  
end
