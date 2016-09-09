# encoding: UTF-8
require 'nokogiri'

require 'test_helper'

class BentoSearchHelperTest < ActionView::TestCase
  include BentoSearchHelper

  MockEngine = BentoSearch::MockEngine

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

  def test_custom_partial
    results = MockEngine.new(:for_display => {:item_partial => "test_custom_item_partial"})

    bento_search(results)

    assert_select("p.custom_item_partial")
  end

  def test_with_failed_search
    results = BentoSearch::Results.new
    results.error = {:error => true}

    assert results.failed?

    response = Nokogiri::HTML(bento_search(results))

    assert (no_results_div = response.at_css(".bento_search_error.alert.alert-error")), "has search_error div"

    assert no_results_div.text =~ Regexp.new(I18n.translate("bento_search.search_error")), "has error message"

    assert_nil response.at_css(".bento_item")
  end

  def test_with_empty_results
    results = MockEngine.new(:num_results => 0).search(:query => "foo")

    response = Nokogiri::HTML(bento_search(results))

    assert (no_results_div = response.at_css(".bento_search_no_results")), "has no_results div"
    assert no_results_div.text =~ (Regexp.new(I18n.translate("bento_search.no_results")))

    assert_nil response.at_css(".bento_item"), "has no results message"
  end

  def test_with_engine_arg
    engine = MockEngine.new
    bento_search(engine, :query => "QUERY")

    assert_select("div.bento_item", 10).each_with_index do |node, i|
      assert_select node, "*", /QUERY/
      assert_select node, "*", /#{i +1 }/
    end
  end

  def test_with_registered_id
    BentoSearch.register_engine("test_engine") do |conf|
      conf.engine = "MockEngine"
    end

    bento_search("test_engine", :query => "QUERY")

    assert_select("div.bento_item", 10).each_with_index do |node, i|
      assert_select node, "*", /QUERY/
      assert_select node, "*", /#{i +1 }/
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
    results = Nokogiri::HTML(results)


    div = results.at_css(".bento_search_ajax_wait")
    assert div, "produces div.bento_search_ajax_wait"

    assert_equal "ajax_auto", div["data-bento-search-load"], "has data-bento-search-load attribute"

    assert_present div["data-bento-ajax-url"]
    url = URI.parse(div["data-bento-ajax-url"])
    assert_equal "/bento/test_engine", url.path

    query = CGI.parse(url.query.gsub("&amp;", "&")) # gsub weirdness of HTML::Tag
    assert_equal ["QUERY"], query["query"]
    assert_empty query["load"]

    # hidden loading msg
    loading_msg = div.at_css(".bento_search_ajax_loading")
    assert_present loading_msg, "bento_search_ajax_loading present"
    assert_match /display\:none/, loading_msg["style"], "loading has CSS style hidden"

    assert div.at_css("noscript"), "has <noscript> tag"

    assert (img = loading_msg.at_css("img")), "Has spinner gif"
    assert_equal I18n.translate("bento_search.ajax_loading"), img["alt"]
  end

  def test_ajax_triggered_load
    BentoSearch.register_engine("test_engine") do |conf|
      conf.engine = "MockEngine"
    end

    results = bento_search("test_engine", :query => "QUERY", :load => :ajax_triggered)
    results = Nokogiri::HTML(results)

    div = results.at_css(".bento_search_ajax_wait")
    assert div, "produces div.bento_search_ajax_wait"
    assert_equal "ajax_triggered", div["data-bento-search-load"], "has data-bento-search-load attribute"

    # hidden loading msg
    loading_msg = div.at_css(".bento_search_ajax_loading")
    assert_present loading_msg, "bento_search_ajax_loading present"
    assert_match /display\:none/, loading_msg["style"], "loading has CSS style hidden"
  end


  def test_sort_hash_for
    tested_keys = %w{title_asc date_desc relevance author_asc}

    sort_definitions = {}
    tested_keys.each {|k| sort_definitions[k] = {}}

    engine = MockEngine.new(:sort_definitions => sort_definitions)

    hash = bento_sort_hash_for(engine)

    assert_present hash

    tested_keys.each do |key|
      assert_equal key, hash[ I18n.translate(key, :scope => "bento_search.sort_keys") ]
    end
  end

  def test_sort_hash_for_no_i18n
    # If there's no 18n key available, use reasonable humanized approximation

    engine = MockEngine.new(:sort_definitions => {"no_key_test" => {}})

    hash = bento_sort_hash_for(engine)

    assert_present hash

    key = hash.key("no_key_test")

    assert_no_match /translation missing/, key

    assert_equal "No Key Test", key
  end

  def test_field_hash_for
    # generic
    hash = bento_field_hash_for(nil)

    assert_equal I18n.t("bento_search.search_fields").invert, hash

    # specific engine
    engine = MockEngine.new(:search_field_definitions => {
        :mytitle => {:semantic => :title},
        :myauthor => {:semantic => :author},
        :myissn => {:semantic => :issn},
        :mycustom => {}
    })
    hash = bento_field_hash_for(engine)
    expected = { I18n.t("bento_search.search_fields.title") => 'title',
      I18n.t("bento_search.search_fields.author") => 'author',
      I18n.t("bento_search.search_fields.issn") => 'issn',
    }
    assert_equal expected, hash

    # only
    hash = bento_field_hash_for(engine, :only => :author)
    assert_equal( {"Author" => "author"}, hash )
    hash = bento_field_hash_for(engine, :only => ["author", "title"])
    assert_equal( {"Title" => "title", "Author" => "author"}, hash )

    # except


  end

  def test_bento_decorate
    item = BentoSearch::ResultItem.new(:title => "foo")

    decorated = bento_decorate(item)

    assert_kind_of BentoSearch::StandardDecorator, decorated

    assert_equal "foo", decorated.title

    assert decorated.send("_h").respond_to?(:url_for), "has ActionView helpers available internally"
  end

  def test_bento_decorate_with_yield
    item = BentoSearch::ResultItem.new(:title => "foo")

    got_here = false

    bento_decorate(item) do |decorated|
      got_here = true
      assert_equal "foo", decorated.title
    end

    assert got_here, "Yielded block is called"

  end

  class SomeDecorator < BentoSearch::StandardDecorator ; end

  def test_bento_decorate_with_custom_decorator
    item = BentoSearch::ResultItem.new(:title => "foo", :decorator => "BentoSearchHelperTest::SomeDecorator")

    decorated = bento_decorate(item)

    assert_kind_of BentoSearchHelperTest::SomeDecorator, decorated
  end




end
