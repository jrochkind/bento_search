require 'test_helper'

class ParseSearchArgumentsTest < ActiveSupport::TestCase
  MockEngine = BentoSearch::MockEngine

  class Dummy
    include BentoSearch::SearchEngine

    def search_implementation(args)
      # no-op for now
      BentoSearch::Results.new
    end

    def test_parse(*args)
      # original method is protected, this is a lame way
      # to expose it.
      parse_search_arguments(*args)
    end

    def max_per_page
      40
    end

    def search_field_definitions
      {
        "my_title" => {:semantic => :title},
        "my_author" => {:semantic => :author},
        "my_other" => nil
      }
    end

  end


  def test_single_arg
    d = Dummy.new

    args = d.test_parse("query")

    assert_equal( {:query => "query", :per_page => BentoSearch::SearchEngine::DefaultPerPage }, args )
  end

  def test_two_arg
    d = Dummy.new

    args = d.test_parse("query", :arg => "1")

    assert_equal( {:query => "query", :arg => "1", :per_page => BentoSearch::SearchEngine::DefaultPerPage }, args )
  end



  def test_convert_page_to_start
    d = Dummy.new

    args = d.test_parse(:query => "query", :page => 1, :per_page => 20)

    assert_equal 0, args[:start]
    assert_equal 1, args[:page]
    assert_equal 20, args[:per_page]

    args = d.test_parse(:query => "query", :page => 3, :per_page => 20)

    assert_equal 40, args[:start]
    assert_equal 3, args[:page]
    assert_equal 20, args[:per_page]
  end

  def test_convert_start_to_page
    d = Dummy.new

    # rounds down to get closest 'page' if need be.
    args = d.test_parse(:query => "query", :start => '19', :per_page => '20')

    assert_equal 19, args[:start]
    assert_equal 1,  args[:page]

    args = d.test_parse(:query => "query", :start => '20', :per_page => '20')
    assert_equal 2,  args[:page]
  end


  def test_pagination_to_integer
    d = Dummy.new

    args = d.test_parse(:query => "query", :page => "1", :per_page => "20")
    assert_equal 0, args[:start]
    assert_equal 1, args[:page]
    assert_equal 20, args[:per_page]

    args = d.test_parse(:query => "query", :start => "20", :per_page => "20")
    assert_equal 20, args[:start]
    assert_equal 20, args[:per_page]

  end

  def test_ignore_blank_pagination_args
    d = Dummy.new

    args = d.test_parse(:query => "query", :page => "", :per_page => "", :start => "")

    assert ! (args.has_key? :page)
    assert ! (args.has_key? :start)
    assert  (args.has_key? :per_page) # default per page always provided
  end

  def test_enforce_max_per_page
    d = Dummy.new

    assert_raise(ArgumentError) { d.test_parse(:query => "query", :per_page => 1000) }
  end

  def test_default_per_page
    d = Dummy.new

    args = d.test_parse(:query => "query")
    assert_equal(Dummy::DefaultPerPage, args[:per_page])

    d.configuration[:default_per_page] = 2
    args = d.test_parse(:query => "query")
    assert_equal(2, args[:per_page])
  end

  def test_search_field_keys
    assert_equal ["my_title", "my_author", "my_other"], Dummy.new.search_keys
    assert_equal ["title", "author"], Dummy.new.semantic_search_keys
  end

  def test_semantic_search_map
    assert_equal( {"title" => "my_title", "author" => "my_author"},
      Dummy.new.semantic_search_map)
  end

  def test_translate_search_field_semantics
    d = Dummy.new

    args = d.test_parse(:query => "query", :semantic_search_field => :title)

    assert ! (args.has_key? :semantic_search_field), "translates semantic_search_field to search_field"
    assert_equal "my_title", args[:search_field]

    assert_raise(ArgumentError, "Raises for undefined semantic_search_field when asked") do
      d.test_parse(:query => "query", :semantic_search_field => :subject, :unrecognized_search_field => :raise)
    end
    # without the :unrecognized_search_field => :raise, ignore
    args = d.test_parse(:query => "query", :semantic_search_field => :subject)
    assert_nil args[:search_field]
  end

  def test_unrecognized_search_field
    d = Dummy.new
    assert_raise(ArgumentError, "Raises for undefined search field when asked") do
      d.test_parse(:query => "query", :search_field => "I_made_this_up", :unrecognized_search_field => "raise")
    end
    assert_nothing_raised do
      d.test_parse(:query => "query", :search_field => "I_made_this_up")
    end

    # combine config and args
    engine = BentoSearch::MockEngine.new(:unrecognized_search_field => :raise)
    assert_raise(ArgumentError, "Raises for undefined search field when asked") do
      engine.normalized_search_arguments(:query => "query", :search_field => "I_made_this_up")
    end
    assert_nothing_raised do
      engine.normalized_search_arguments(:query => "query", :search_field => "I_made_this_up", :unrecognized_search_field => :ignore)
    end

  end


  describe "multi-field search" do
    it "complains with multi-query and search_field" do
      engine = MockEngine.new(:multi_field_search => true)
      assert_raises(ArgumentError) { engine.search(:query => {:title => "foo"}, :semantic_search_field => :author)}
      assert_raises(ArgumentError) { engine.search(:query => {:title => "foo"}, :search_field => "something")}
    end

    it "rejects if search engine does not support" do
      engine = MockEngine.new(:multi_field_search => false)
      assert_raises(ArgumentError) { engine.search(:query => {:title => "title", :author => "author"}) }
    end

    it "converts semantic search fields" do
      engine = MockEngine.new(:multi_field_search => true,
        :search_field_definitions => {
          "internal_title_field"  => {:semantic => :title},
          "internal_author_field" => {:semantic => :author}
        })

      engine.search(:query => {:title => "title query", :author => "author query"})

      assert_equal(
        { "internal_title_field"  => "title query",
          "internal_author_field" => "author query"},
        engine.last_args[:query]
      )
    end

    it "passes through other fields" do
      engine = MockEngine.new(:multi_field_search => true,
        :search_field_definitions => {
          "internal_title_field"  => {:semantic => :title},
          "internal_author_field" => {:semantic => :author}
        })

      engine.search(:query => {"internal_title_field" => "query", "other field" => "query"})

      assert_equal(
       {"internal_title_field" => "query", "other field" => "query"},
        engine.last_args[:query]
      )
    end

    it "complains on unrecognized field if configured" do
      engine = MockEngine.new(:multi_field_search => true,
        :unrecognized_search_field => "raise",
        :search_field_definitions => {
          "internal_title_field"  => {:semantic => :title},
          "internal_author_field" => {:semantic => :author}
        })
      assert_raises(ArgumentError) do
        engine.search(:query => {"internal_title_field" => "query", "other field" => "query"})
      end
    end
  end

  def test_semantic_blank_ignored
    d = Dummy.new

    args1 = d.test_parse(:query => "query", :semantic_search_field => nil)
    args2 = d.test_parse(:query => "query", :semantic_search_field => nil)

    assert_nil args1[:search_field]
    assert_nil args2[:search_field]
  end

  def test_semantic_string_or_symbol
    d = Dummy.new

    args1 = d.test_parse(:query => "query", :semantic_search_field => :title)
    args2 = d.test_parse(:query => "query", :semantic_search_field => "title")

    assert_equal args1, args2
  end

  def test_converts_sort_to_string
    d = Dummy.new

    args = d.test_parse(:query => "query", :sort => :title_asc)

    assert_equal "title_asc", args[:sort]
  end

  def test_sets_timing
    d = Dummy.new
    results = d.search("foo")

    assert_not_nil results.timing
    assert_not_nil results.timing_ms
  end

  def test_passes_arbitrary_keys
    d = Dummy.new
    args = d.test_parse(:query => "foo", :custom_auth => true)

    assert_present args[:custom_auth]
    assert_equal true, args[:custom_auth]

  end

  def test_rescues_exceptions
    horrible_engine = Class.new do
      include BentoSearch::SearchEngine

      def search_implementation(args)
        raise BentoSearch::RubyTimeoutClass.new("I am a horrible engine")
      end
    end

    engine = horrible_engine.new

    results =  engine.search("cancer")

    assert_not_nil results
    assert results.failed?, "results marked failed"
    assert_not_nil results.error[:exception], "results.error has exception"

    assert_equal "I am a horrible engine", results.error[:exception].message, "results.error has right exception"
  end

  def test_cover_consistency_api
    d = Dummy.new()
    assert_nil d.engine_id
    assert_equal({}, d.display_configuration)

    d = Dummy.new(id: 'test', for_display: { testkey: 'test' })
    assert_equal 'test', d.engine_id
    assert_equal({ testkey: 'test' }, d.display_configuration)

  end

end

