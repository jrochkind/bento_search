require 'test_helper'

class PrimoEngineTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  @@host_port   = (ENV['PRIMO_HOST_PORT'] || 'EXAMPLE.ORG:80' )
  @@institution = (ENV['PRIMO_INSTITUTION'] || 'DUMMY_INSTITUTION')
  
  VCR.configure do |c|
    c.filter_sensitive_data("EXAMPLE.ORG:80", :primo) { @@host_port }
    c.filter_sensitive_data("DUMMY_INSTITUTION", :primo) { @@institution }
  end
  
  def setup
    @engine = BentoSearch::PrimoEngine.new(:host_port => @@host_port, :institution => @@institution)
  end
  
  
  test_with_cassette("search smoke test", :primo) do    
    results = @engine.search_implementation(:query => "globalization from below", :per_page => 10)
    
    assert_present results, "has results"
    
    assert_present results.total_items, "has total_items"
    
    first = results[6]
    
    # not every result has every field, but at time we recorded
    # with VCR, this result for this search did. Sorry, a bit fragile. 
    # publisher
    %w{format_str format title authors volume issue start_page end_page journal_title issn doi abstract}.each do |attr|
      assert_present first.send(attr), "must have #{attr}"
    end
    
  end
  
end
