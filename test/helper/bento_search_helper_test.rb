require 'test_helper'

class BentoSearchHelperTest < ActionView::TestCase
  include BentoSearchHelper
  
  
  def teardown
    BentoSearch.reset_engine_registrations!
  end

  

  
  def setup
    # Make routing work
    @routes = Rails.application.routes        
  end
  
  def test_with_results_arg
    results = MockEngine.new.search(:query => "foo")
    bento_search(results)    
    
    assert_select("div.bento_item", 10)    
  end
  
  def test_with_failed_search
    results = BentoSearch::Results.new
    results.error = {:error => true}
    
    assert results.failed?
    
    response = HTML::Document.new(bento_search(results))
    
    assert (no_results_div = response.find(:attributes => {:class => "bento_search_error"})), "has search_error div"
    
    assert no_results_div.match(Regexp.new I18n.translate("bento_search.search_error")), "has error message"

    assert_nil response.find(:attributes => {:class => "bento_item"})    
  end
  
  def test_with_empty_results
    results = MockEngine.new(:num_results => 0).search(:query => "foo")
    
    response = HTML::Document.new(bento_search(results))
    
    assert (no_results_div = response.find(:attributes => {:class => "bento_search_no_results"})), "has no_results div"
    assert no_results_div.match(Regexp.new(I18n.translate("bento_search.no_results")))

    
    assert_nil response.find(:attributes => {:class => "bento_item"}), "has no results message"
  end
  
  def test_with_engine_arg
    engine = MockEngine.new
    bento_search(engine, :query => "QUERY")
    
    assert_select("div.bento_item", 10).each_with_index do |node, i|
      node.match /QUERY/
      node.match /#{i +1 }/      
    end    
  end
  
  def test_with_registered_id
    BentoSearch.register_engine("test_engine") do |conf|
      conf.engine = "MockEngine"
    end
    
    bento_search("test_engine", :query => "QUERY")
    
    assert_select("div.bento_item", 10).each_with_index do |node, i|
      node.match /QUERY/
      node.match /#{i +1 }/      
    end    
  end
  
  def test_ajax_load_without_registration
    assert_raises(ArgumentError) { bento_search(MockEngine.new, :load => :ajax_auto) }
  end
  
  def test_ajax_load 
    BentoSearch.register_engine("test_engine") do |conf|
      conf.engine = "MockEngine"
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
    
    assert (img = div.find(:tag => "img")), "Has spinner gif"
    assert_equal I18n.translate("bento_search.ajax_loading"), img.attributes["alt"]
  end
    
    

  
end
