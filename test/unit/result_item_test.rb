require 'test_helper'



class ResultItemTest < ActiveSupport::TestCase
  ResultItem = BentoSearch::ResultItem
  
  def test_has_custom_data
    r = ResultItem.new
    
    assert_not_nil r.custom_data
    assert_kind_of Hash, r.custom_data
  end
  
  def test_can_dup_and_set_attributes
    # Need to be able to dup and set at least basic attributes without
    # changing original. Used by SummonEngine for making sure
    # openurl does not have highlighting tags in it when generated. 
    
    r = ResultItem.new(:title => "original")
    
    assert_equal "original", r.title
    
    dup = r.dup
    dup.title = "new"
    
    assert_equal "new", dup.title
    assert_equal "original", r.title
    
    assert_not_same dup, r        
  end
  
  def test_openurl_disabled
    r = ResultItem.new(:title => "original")
    
    assert_present r.to_openurl
    
    r.openurl_disabled = true
    
    assert_nil r.to_openurl    
  end
  
  def test_language
    r = ResultItem.new(:title => "something", :language_code => "en")    
    assert_equal "en",      r.language_code
    assert_equal "English", r.language_str
    
    r = ResultItem.new(:title => "something", :language_code => "eng")
    assert_equal "eng",      r.language_code
    assert_equal "English", r.language_str
    
    # language_str override
    r = ResultItem.new(:title => "something", :language_code => "en", :language_str => "Weird English")
    assert_equal "en",            r.language_code
    assert_equal "Weird English", r.language_str
    
    # language_str only
    r = ResultItem.new(:title => "something", :language_str => "English")
    assert_nil r.language_code
    assert_equal "English", r.language_str
    
  end
  
end
