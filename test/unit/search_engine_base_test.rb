require 'test_helper'

class ParseSearchArgumentsTest < ActiveSupport::TestCase
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
    
    def self.max_per_page
      40
    end
    
    def self.search_field_definitions
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
    
    assert_equal( {:query => "query"}, args )        
  end
  
  def test_two_arg
    d = Dummy.new
    
    args = d.test_parse("query", :arg => "1")
    
    assert_equal( {:query => "query", :arg => "1"}, args )
  end
  
  def test_illegal_pagination_args
    d = Dummy.new
    # can't do start and page both
    assert_raise(ArgumentError) {  d.test_parse("query", :page => 4, :start => 40, :per_page => 20)  }
    # start or page need per_page
    assert_raise(ArgumentError) { d.test_parse("query", :page => 4) }
    assert_raise(ArgumentError) { d.test_parse("query", :start => 40) }    
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
    assert ! (args.has_key? :per_page)    
  end
  
  def test_enforce_max_per_page
    d = Dummy.new
    
    assert_raise(ArgumentError) { d.test_parse(:query => "query", :per_page => 1000) }        
  end
    
  def test_search_field_keys    
    assert_equal ["my_title", "my_author", "my_other"], Dummy.search_keys
    assert_equal [:title, :author], Dummy.semantic_search_keys
  end
  
  def test_semantic_search_map
    assert_equal( {:title => "my_title", :author => "my_author"}, 
                  Dummy.semantic_search_map)
  end
  
  def test_translate_search_field_semantics
    d = Dummy.new
    
    args = d.test_parse(:query => "query", :semantic_search_field => :title)
    
    assert ! (args.has_key? :semantic_search_field), "translates semantic_search_field to search_field"
    assert_equal "my_title", args[:search_field]
    
    assert_raise(ArgumentError, "Raises for undefined semantic_search_field") do
      d.test_parse(:query => "query", :semantic_search_field => :subject)
    end
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
  end
    
  
  
end

