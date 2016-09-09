require 'test_helper'



class SearchEngineTest < ActiveSupport::TestCase
  MockEngine = BentoSearch::MockEngine

    test "takes configuration" do
      conf = Confstruct::Configuration.new( :foo => "foo", :bar => "bar", :top => {:next => "required key"} )
      engine = MockEngine.new(conf)

      assert_not_nil engine.configuration
      assert_equal "foo", engine.configuration.foo
      assert_equal "bar", engine.configuration.bar
      assert_equal "required key", engine.configuration.top.next
    end

    test "nested configuration with hash" do
      # possible bug in Confstruct make sure we're working around
      # if needed.
      # https://github.com/mbklein/confstruct/issues/14
      engine = MockEngine.new("top" => {"one" => "two"})

      assert_equal "two", engine.configuration.top.one
    end

    test "nested required config key" do
      requires_class = Class.new(MockEngine) do
        def self.required_configuration
          ["required.mykey"]
        end
      end

      assert_raise ArgumentError do
        requires_class.new
      end

      assert_raise ArgumentError do
        requires_class.new(:requires => {})
      end

      assert_raise ArgumentError do
        requires_class.new(:required => {:mykey => nil})
      end

      assert_nothing_raised do
        requires_class.new(:required => {:mykey => "foo"})
      end
    end

    test "merges default configuration" do
      @dummy_class = Class.new do
        include BentoSearch::SearchEngine
        def self.default_configuration
          { :one => "default",
            :two => "default",
            :array => [:a, :b, :c],
            :nested => {:one => "default", :two => "default"}
          }
        end
      end

      engine = @dummy_class.new( :two => "new", :array => ["one", "two"], :nested => {:two => "new"}, :required => {:mykey => "required key"} )

      assert_kind_of Confstruct::Configuration, engine.configuration
      assert_equal "default"      , engine.configuration.one
      assert_equal "new"          , engine.configuration.two
      assert_equal "default"      , engine.configuration.nested.one
      assert_equal "new"          , engine.configuration.nested.two
      assert_equal ["one", "two"] , engine.configuration.array
    end

    test "no default configuration" do
      @dummy_class = Class.new do
        include BentoSearch::SearchEngine
      end

      engine = @dummy_class.new( :one => "one" )

      assert_kind_of Confstruct::Configuration, engine.configuration
      assert_equal "one", engine.configuration.one
    end

    test "sets metadata on results" do
      engine = MockEngine.new(:id => "foo")

      results = engine.search(:query => "cancer", :per_page => 20)

      assert_present results.search_args
      assert_equal "foo", results.engine_id

      pagination = results.pagination
      assert_present pagination

      assert_equal 20, pagination.per_page
      assert_equal 1, pagination.current_page
      assert_equal 1, pagination.start_record
      assert_equal 20, pagination.end_record
      assert pagination.first_page?

      assert_present pagination.total_pages
      assert_present pagination.count_records

    end

    test "sets metadata on items" do
      engine = MockEngine.new(:id => "foo", :for_display => {:mykey => "value", :decorator => "Foo"})
      results = engine.search(:query => "cancer")
      record = results.first

      assert_present record.engine_id
      assert_present record.display_configuration
      assert_present record.decorator
    end

    test "failed sets metadata on results" do
      engine = MockEngine.new(:id => "fail_engine", :error => {:message => "failed"}, :for_display => {:foo => "foo"})

      results = engine.search(:query => "cancer", :per_page => 20)

      assert          results.failed?
      assert_present  results.error
      assert_equal    "fail_engine", results.engine_id
      assert_present  results.search_args
      assert_equal(  {:foo => "foo"}, results.display_configuration )
    end

    test "auto rescued exception, with proper metadata" do
      engine = MockEngine.new(:id => "raises", :raise_exception_class => BentoSearch::RubyTimeoutClass.name, :for_display => {:foo => "foo"})

      results = engine.search("foo", :per_page => 20)

      assert          results.failed?, "marked failed"
      assert_present  results.error
      assert_equal    "raises", results.engine_id
      assert_present  results.search_args
      assert_equal    "foo", results.search_args[:query]

      assert_equal(  {:foo => "foo"}, results.display_configuration )
    end


    test "has empty :for_display config" do
      engine = MockEngine.new

      assert_not_nil engine.configuration.for_display
    end

    test "error results still filled out okay" do
      engine = MockEngine.new(:error => {:msg => "forced error"}, :id => "test")

      results = engine.search("foo")

      assert_present results.search_args
      assert_equal "test", results.engine_id

      pagination = nil
      assert_nothing_raised {  pagination = results.pagination  }

      assert_present pagination
      assert_equal 0, pagination.count_records

    end


    test "carries display configuration over to results" do
      engine = MockEngine.new(:id => "foo",
        :for_display => {:foo => "bar", :nested => {"one" => "two"}}
      )

      results = engine.search("foo")

      assert_present  results.display_configuration
      assert_present  results.display_configuration.foo
      assert_present  results.display_configuration.nested.one
    end

end
