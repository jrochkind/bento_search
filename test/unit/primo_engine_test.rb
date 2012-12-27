require 'test_helper'

class PrimoEngineTest < ActiveSupport::TestCase
  extend TestWithCassette
 
  # dummy host needs to be in all lowercase, and not explicitly
  # say '80' to work right with VCR 
  @@host_port   = (ENV['PRIMO_HOST_PORT'] || 'example.org' )
  @@institution = (ENV['PRIMO_INSTITUTION'] || 'DUMMY_INSTITUTION')
  
  VCR.configure do |c|
    c.filter_sensitive_data("example.org", :primo) { @@host_port }
    c.filter_sensitive_data("DUMMY_INSTITUTION", :primo) { @@institution }
  end
  
  def setup
    @engine = BentoSearch::PrimoEngine.new(:host_port => @@host_port, :institution => @@institution)
  end
  
  test("sort params") do
    url = @engine.construct_query(:query => "cancer", :sort => "title_asc")    
    query_params = CGI.parse( URI.parse(url).query )    
    assert_equal ["stitle"], query_params["sortField"]
    
    # for 'relevance', no sortField should be passed to primo api
    
    url = @engine.construct_query(:query => "cancer", :sort => "relevance")
    query_params = CGI.parse( URI.parse(url).query )    
    assert ! query_params.has_key?("sortField"), "for relevance sort, no sortField should be passed to primo api"
  end
  
  
  test_with_cassette("search smoke test", :primo) do    
    results = @engine.search_implementation(:query => "globalization from below", :per_page => 10)
    
    assert_present results, "has results"
    
    assert_present results.total_items, "has total_items"
    
    first = results[6]
    
    # not every result has every field, but at time we recorded
    # with VCR, this result for this search did. Sorry, a bit fragile. 
    # publisher
    %w{format_str format title authors volume issue start_page end_page journal_title issn doi abstract id}.each do |attr|
      assert_present first.send(attr), "must have #{attr}"
    end
    
  end

  # test of highlighting assumes if search for 'cancer', then
  # that word will be in title of first hit.   
  test_with_cassette("proper tags for snippets", :primo) do
    results = @engine.search("cancer")
    
    first = results.first
    
    assert first.title.html_safe?, "title is HTML safe"
    
    assert_include first.title, '<b class="bento_search_highlight">' 
    
  end
  
end
