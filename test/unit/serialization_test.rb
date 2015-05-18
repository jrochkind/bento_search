require 'test_helper'



class SerializationTest < ActiveSupport::TestCase
  ResultItem = BentoSearch::ResultItem

  setup do
    @init_hash = {:title => "something", :language_code => "en", 
                  :link_is_fulltext => true,
                  :snippets => ["snippet one", "snippet two"]}
    @result_item = ResultItem.new(@init_hash)
  end

  def test_serialization
    

    r = ResultItem.new(@init_hash)

    hash = r.serializable_hash

    r2 = ResultItem.from_serializable_hash(hash)

    assert_kind_of ResultItem, r2

    @init_hash.each_pair do |key, value|
      assert_equal value, r2.instance_variable_get("@#{key}")
    end
  end

  def test_author_serialization
    hash = {:first => "Jonathan", :last => "Rochkind", :middle => "A", :display => "Rochkind, Jonathan A."}
    a = BentoSearch::Author.new(hash)

    a2 = BentoSearch::Author.from_json( a.dump_to_json )

    hash.each_pair do |key, value|
      assert_equal value, a2.send(key)
    end
  end

  def test_json_serialization
    json_str = @result_item.dump_to_json

    assert_kind_of String, json_str

    r2 = ResultItem.from_json(json_str)

    @init_hash.each_pair do |key, value|
      assert_equal value, r2.instance_variable_get("@#{key}")
    end
  end

  def test_html_safe_serialization
    r = ResultItem.new(:title => "<b>foo</b>".html_safe)

    r2 = ResultItem.from_json( r.dump_to_json )

    assert r2.title.html_safe?
    assert_equal "<b>foo</b>", r2.title
  end

  def test_result_item_authors
    r = ResultItem.new(:title => "foo")
    r.authors << BentoSearch::Author.new(:first => "Jonathan", :last => "Rochkind")

    json_str = r.dump_to_json
  end
  

end