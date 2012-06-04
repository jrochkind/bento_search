require 'test_helper'

class BentoSearchHelperTest < ActionView::TestCase
  include BentoSearchHelper
  
  
  def teardown
    BentoSearch.reset_engine_registrations!
  end

  
  class DummySearcher
    include BentoSearch::SearchEngine
    
    def search_implementation(args)
      return BentoSearchHelperTest.dummy_results(:title_words => args[:query])
    end
  end
  
  def setup
    # Make routing work
    @routes = Rails.application.routes
    
    @dummy_results = self.class.dummy_results
  end
  
  def test_with_results_arg
    bento_search(@dummy_results)    
    
    assert_select("div.bento_item", 10)    
  end
  
  def test_with_engine_arg
    engine = DummySearcher.new
    bento_search(engine, :query => "QUERY")
    
    assert_select("div.bento_item", 10).each_with_index do |node, i|
      node.match /QUERY/
      node.match /#{i +1 }/      
    end    
  end
  
  def test_with_registered_id
    BentoSearch.register_engine("test_engine") do |conf|
      conf.engine = "BentoSearchHelperTest::DummySearcher"
    end
    
    bento_search("test_engine", :query => "QUERY")
    
    assert_select("div.bento_item", 10).each_with_index do |node, i|
      node.match /QUERY/
      node.match /#{i +1 }/      
    end    
  end
  
  def test_ajax_load_without_registration
    assert_raises(ArgumentError) { bento_search(BentoSearchHelperTest::DummySearcher.new, :load => :ajax_auto) }
  end
  
  def test_ajax_load 
    BentoSearch.register_engine("test_engine") do |conf|
      conf.engine = "BentoSearchHelperTest::DummySearcher"
    end
    
    results = bento_search("test_engine", :query => "QUERY", :load => :ajax_auto)
    results = HTML::Document.new(results)
    
    
    div = results.find(:attributes => {:class => "bento_search_ajax_wait"})
    assert div, "produces div.bento_search_ajax_wait"
    
    assert_present div.attributes["data-bento-ajax-url"]    
    url = URI.parse(div.attributes["data-bento-ajax-url"])    
    assert_equal "/bento/test_engine", url.path
    
    query = CGI.parse(url.query.gsub("&amp;", "&")) # gsub weirdness of HTML::Tag
    assert_equal ["QUERY"], query["query"]
    assert_empty query["load"]
        
    assert div.find(:tag => "noscript"), "has <noscript> tag"
    
    
  end
    
    
  def self.dummy_results(options = {})
    dummy_results = BentoSearch::Results.new
    1.upto(10) do |i|
      dummy_results << BentoSearch::ResultItem.new(:title => "Item #{i}: #{options[:title_words]}")
    end
    return dummy_results
  end
  
end
