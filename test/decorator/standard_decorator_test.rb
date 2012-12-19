require 'test_helper'



class StandardDecoratorTest < ActionView::TestCase
  include BentoSearch
  
  def decorator(hash = {})
    StandardDecorator.new(
      ResultItem.new(hash), nil
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
    
  
end
