require 'test_helper'



class ResultItemDisplayTest < ActiveSupport::TestCase
  Author = BentoSearch::Author
  ResultItem = BentoSearch::ResultItem
  
  test "author with first and last" do
    author = Author.new(:last => "Smith", :first => "John")
    
    str = ResultItem.new.author_display(author)
    
    assert_equal "Smith, J", str    
  end
  
  test "author with display form and just last" do
    author = Author.new(:last => "Smith", :display => "Display Form")
    
    str = ResultItem.new.author_display(author)
    
    assert_equal "Display Form", str
  end
  
  test "Author with just last" do
    author = Author.new(:last => "Johnson")
    
    str = ResultItem.new.author_display(author)
    
    assert_equal "Johnson", str
    
  end
  
  test "Missing title" do
    assert_equal I18n.translate("bento_search.missing_title"), ResultItem.new.complete_title
  end
  
  test "language label nil if default" do
    I18n.with_locale(:'en-GB') do
      item = ResultItem.new(:language_code => 'en')      
      assert_nil item.display_language
      
      item = ResultItem.new(:language_code => 'es')
      assert_equal "Spanish", item.display_language      
    end
  end
    
  
end
