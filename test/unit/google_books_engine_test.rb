require 'test_helper'

class GoogleBooksEngineTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  def setup    
    @engine = BentoSearch::GoogleBooksEngine.new
    # tell it not to send our bad API key
  end

  
  
  test_with_cassette("search", :gbs) do
    results = @engine.search("cancer")
    
    assert_kind_of BentoSearch::Results, results
    
    assert ! results.failed?
    
    assert_not_nil results.total_items
    assert_equal 0, results.start
    assert_equal 10, results.per_page
    
    assert_not_empty results
    
    first = results.first
    
    assert_kind_of BentoSearch::ResultItem, first
    
    assert_not_empty    first.id
    
    assert_not_empty    first.title
    assert_not_empty    first.publisher
    assert_not_empty    first.link
    assert_not_empty    first.format
    assert_not_nil      first.year
    assert_not_empty    first.abstract
    assert              first.abstract.html_safe?
    
    assert_present      first.language_code
    
    assert_not_empty    first.authors
    assert_not_empty    first.authors.first.display
    
    # assume at least one thing in the result set has an ISBN to test
    # our ISBN-setting code. 
    assert_present      results.find {|r| r.isbn.present? }
    
    assert_present      first.custom_data[:viewability]
    
    assert_not_nil      first.link_is_fulltext?
  end
  
  test_with_cassette("pagination", :gbs) do
    results = @engine.search("cancer", :per_page => 20, :start => 40)
    
    assert ! results.failed?
    
    assert_equal 20, results.length
    
    assert_equal 20, results.per_page
    assert_equal 20, results.size
    assert_equal 40, results.start
  end

    
  
  test_with_cassette("error condition", :gbs) do       
    # send a bad API key on purpose to get error
    @engine = BentoSearch::GoogleBooksEngine.new(:api_key => "BAD_KEY")
    
    results = @engine.search("cancer")      
    
    assert results.failed?
    assert_not_nil results.error
    assert_not_nil results.error[:status]
    assert_not_nil results.error[:error_info]            
  end
  
  test_with_cassette("empty results", :gbs) do
    results = @engine.search '"mongy frongy alkdjf mzytladf"'
    
    assert ! results.failed?
    assert_equal 0, results.total_items
  end

  
  
  def test_sort_construction
    url = @engine.send(:args_to_search_url, :query => "cancer", :sort => "date_desc")
    
    assert_match '&orderBy=newest', url
    
    url = @engine.send(:args_to_search_url, :query => "cancer", :sort => "relevance")
    
    assert_not_match "&orderBy", url    
  end
  
  def test_fielded_search    
    # Have to use protected methods to get at what we want to test. 
    # Is there a better way to factor this for testing?
    norm_args = @engine.send(:parse_search_arguments, 'cancer "by radiation"', :search_field => :intitle)
    url = @engine.send(:args_to_search_url, norm_args)
    
    query_params = CGI.parse( URI.parse(url).query )
    
    assert_match /^|\sintitle\:cancer\s|$/, query_params["q"].first
    assert_match /^|\sintitle\:"by radiation"\s|$/, query_params["q"].first
  end
    
  
end
