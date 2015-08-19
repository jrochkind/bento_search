require 'test_helper'



class SerializationTest < ActiveSupport::TestCase
  ResultItem = BentoSearch::ResultItem
  MockEngine = BentoSearch::MockEngine

  setup do
    @init_hash = {:title => "something", 
                  :unique_id => "AAA11212",
                  :openurl_disabled => true,
                  :link => "http://www.example.org/something",
                  :link_is_fulltext => true,
                  :format => "Article",
                  :year => 2000,
                  :publication_date => Date.new(2000,1,1),
                  :volume => "10",
                  :issue => "22",
                  :start_page => "122",
                  :end_page => "124",
                  :language_code => "en",
                  :language_str => "English 22",
                  :source_title => "Journal of Things",
                  :issn => "12345678",
                  :isbn => "1234567890",
                  :oclcnum => "1",
                  :doi => "10.2.whatever",
                  :pmid => "12121212",
                  :publisher => "Joe Blow",
                  :abstract => "something or other",
                  :openurl_kev_co => "&rft.fake=fake",
                  :format_str => "Something or other",
                  :custom_data => {'foo' => "bar"},
                  :snippets => ["snippet one", "snippet two"]}
    @result_item = ResultItem.new(@init_hash)
  end

  def test_item_serialization
    r = ResultItem.new(@init_hash)

    hash = r.internal_state_hash

    r2 = ResultItem.from_internal_state_hash(hash)

    assert_kind_of ResultItem, r2

    @init_hash.each_pair do |key, value|
      assert_equal value, r2.instance_variable_get("@#{key}")
    end
  end

  class ::SerializationTest::ExampleDecorator < BentoSearch::StandardDecorator
    def title
      "DECORATED TITLE"
    end        
  end

  def test_item_serialization_not_decorated      
    r = ::SerializationTest::ExampleDecorator.new(ResultItem.new(@init_hash), nil)
    
    assert_equal "DECORATED TITLE", r.title

    hash = r.internal_state_hash

    assert_present hash["title"]
    refute_equal "DECORATED TITLE", hash["title"]
  end

  def test_author_serialization
    hash = {:first => "Jonathan", :last => "Rochkind", :middle => "A", :display => "Rochkind, Jonathan A."}
    a = BentoSearch::Author.new(hash)

    a2 = BentoSearch::Author.load_json( a.dump_to_json )

    hash.each_pair do |key, value|
      assert_equal value, a2.send(key)
    end
  end

  def test_item_json_serialization
    json_str = @result_item.dump_to_json

    assert_kind_of String, json_str

    r2 = ResultItem.load_json(json_str)

    @init_hash.each_pair do |key, value|
      assert_equal value, r2.instance_variable_get("@#{key}")
    end
  end

  def test_item_html_safe_serialization
    r = ResultItem.new(:title => "<b>foo</b>".html_safe)

    r2 = ResultItem.load_json( r.dump_to_json )

    assert r2.title.html_safe?
    assert_equal "<b>foo</b>", r2.title
  end

  def test_result_item_authors
    r = ResultItem.new(:title => "foo")
    r.authors << BentoSearch::Author.new(:first => "Jonathan", :last => "Rochkind")

    hash = r.internal_state_hash
    assert_kind_of Array, hash['authors']
    hash['authors'].each do |item|
      assert_kind_of Hash, item
    end

    json_str = r.dump_to_json
    assert_kind_of String, json_str

    r2 = ResultItem.load_json( json_str )
    assert_kind_of Array, r2.authors
    assert r2.authors.length == 1

    au = r2.authors.first
    assert_kind_of BentoSearch::Author, au
    assert_equal "Jonathan", au.first
    assert_equal "Rochkind", au.last
  end

  def test_result_item_other_links
    r = ResultItem.new(:title => "foo")
    r.other_links << BentoSearch::Link.new(:url => "http://example.org")

    r2 = ResultItem.load_json(  r.dump_to_json  )
    assert_kind_of Array, r2.other_links
    assert r2.other_links.length == 1

    l = r2.other_links.first
    assert_kind_of BentoSearch::Link, l
    assert_equal "http://example.org", l.url
  end

  def test_item_year_and_date
    r = ResultItem.new(:title => "foo", :year => 1991, :publication_date => Date.new(1991, 5, 1))

    r2 = ResultItem.load_json(  r.dump_to_json )

    assert_equal 1991, r2.year
    assert_equal Date.new(1991, 5, 1), r2.publication_date
  end

  class Results < ActionController::TestCase
    test "serialize" do
      engine = MockEngine.new(:id => "foo", 
        :for_display => {:foo => "bar", :nested => {"one" => "two"}}
      )
      
      results = engine.search("foo")

      assert_kind_of Hash, results.internal_state_hash
      assert_equal "foo", results.internal_state_hash["engine_id"]
      assert_kind_of Array, results.internal_state_hash["result_items"]

      assert_kind_of String, results.dump_to_json
      assert_equal results.internal_state_hash, JSON.parse(results.dump_to_json)
    end

    test "de-serialize with no engine ID" do
      engine = MockEngine.new(
        :for_display => {:foo => "bar", :nested => {"one" => "two"}}
      )      
      results = engine.search("foo")

      hash = results.internal_state_hash
      restored = BentoSearch::Results.from_internal_state_hash(hash)
      assert_kind_of BentoSearch::Results, restored
      assert_equal results.size, restored.size
      #assert_equal "foo", restored.engine_id

      json_str = results.dump_to_json
      assert_kind_of String, json_str
      assert_kind_of BentoSearch::Results, BentoSearch::Results.load_json(json_str)
    end

    test "de-serialized can be configured for any engine" do
      create_engine = MockEngine.new()
      restore_engine = MockEngine.new(
        :id => "MyMockEngine",
        :for_display => {:foo => "bar", :nested => {"one" => "two"}, :decorator => "SomeDecorator"}
      )

      json = create_engine.search("foo").dump_to_json

      restored = BentoSearch::Results.load_json(json)
      restore_engine.fill_in_search_metadata_for(restored)

      assert_equal "MyMockEngine", restored.engine_id
      assert_equal restore_engine.configuration.for_display, restored.display_configuration

      assert restored.length > 0

      restored.each do |item|
        assert_equal "MyMockEngine", item.engine_id
        assert_equal restore_engine.configuration.for_display, item.display_configuration
        assert_equal "SomeDecorator", item.decorator
      end
    end

    class RegisteredEngineTest < ActionController::TestCase
      def setup
        BentoSearch.register_engine("mock") do |config|
          config.engine = "MockEngine"
          config.for_display = {:foo => "bar", :nested => {"one" => "two"}, :decorator => "SomeDecorator"}
        end
      end      

    
      def teardown     
        BentoSearch.reset_engine_registrations!
      end

      test "de-serializes with a registered engine ID, restoring context" do
        mock_engine = BentoSearch.get_engine("mock")
        results     = mock_engine.search("query")

        json_str = results.dump_to_json
        assert_kind_of String, json_str

        restored = BentoSearch::Results.load_json(json_str)

        assert_kind_of BentoSearch::Results, restored

        assert_equal "mock", restored.engine_id
        assert_equal mock_engine.configuration.for_display, restored.display_configuration

        assert restored.length > 0

        restored.each do |item|
          assert_equal "mock", item.engine_id
          assert_equal mock_engine.configuration.for_display, item.display_configuration
          assert_equal "SomeDecorator", item.decorator
        end

      end

    end

  end



  

end