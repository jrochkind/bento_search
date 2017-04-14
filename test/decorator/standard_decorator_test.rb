require 'test_helper'



class StandardDecoratorTest < ActionView::TestCase
  include BentoSearch

  def decorator(hash = {})
    StandardDecorator.new(
      ResultItem.new(hash), view
    )
  end


  test "author with first and last" do
    author = Author.new(:last => "Smith", :first => "John")

    str = decorator.author_display(author)

    assert_equal "Smith, J", str
  end

  test "author with display form and just last" do
    author = Author.new(:last => "Smith", :display => "Display Form")

    str = decorator.author_display(author)

    assert_equal "Display Form", str
  end

  test "Author with just last" do
    author = Author.new(:last => "Johnson")

    str = decorator.author_display(author)

    assert_equal "Johnson", str

  end

  test "Missing title" do
    assert_equal I18n.translate("bento_search.missing_title"), decorator.complete_title
  end

  test "language label nil if default" do
    I18n.with_locale(:'en-GB') do
      item = decorator(:language_code => 'en')
      assert_nil item.display_language

      item = decorator(:language_code => 'es')
      assert_equal "Spanish", item.display_language
    end
  end

  test "display_language works with just langauge_str" do
     item = decorator(:language_str => 'German')
     assert_equal "German", item.display_language
  end

  test "display_format with nil format" do
    item = decorator(:format => nil, :format_str => nil)

    display_format = item.display_format

    assert_nil display_format
  end

  test "display_date" do
    item = decorator(:year => 1900)
    assert_equal "1900", item.display_date

    d = Date.new(2010, 5, 5)
    item = decorator(:publication_date => d)
    assert_equal I18n.l(d, :format => "%d %b %Y"), item.display_date

    # if volume and issue, only prints out year
    item = decorator(:publication_date => d, :volume => "101", :issue => "2")
    assert_equal I18n.l(d, :format => "%Y"), item.display_date
  end

  test "html_id with no engine_id" do
    item = decorator(:title => "foo")
    assert_nil item.html_id(nil, nil)

    assert_nil item.html_id("prefix", nil)
    assert_nil item.html_id(nil, 3)

    assert_equal "prefix_3", item.html_id("prefix", 3)
  end

  test "html_id with engine_id" do
    item = decorator(:engine_id => "my_engine")

    assert_equal "my_engine_4", item.html_id(nil, 4)

    assert_equal "override_5", item.html_id("override", 5)
  end

  test "render_summary"  do
    item = decorator(:abstract => "abstract", :snippets => ["snippet"])
    assert_equal "snippet", item.render_summary, "prefer snippet by default"

    item = decorator(:abstract => "abstract")
    assert_equal "abstract", item.render_summary, "use abstract if only thing there"

    item = decorator(:snippets => ['snippet'])
    assert_equal "snippet", item.render_summary, "use snippet if only thing there"

    item = decorator(:abstract => "abstract", :snippets => ["snippet"], :display_configuration => {"prefer_abstract_as_summary" => true})
    assert_equal "abstract", item.render_summary, "prefer abstract when configured"

    item = decorator(:snippets => ["snippet"], :display_configuration => {"prefer_abstract_as_summary" => true})
    assert_equal "snippet", item.render_summary, "use snippet if that's all that's there, even when configured for abstract"

    item = decorator()
    assert_nil item.render_summary, "Okay with no snippet or abstract"
  end

end
