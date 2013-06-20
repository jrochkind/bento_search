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

  def test_language_obj
    # from language_code
    r = ResultItem.new(:title => "something", :language_code => "en")
    assert_present r.language_obj
    assert_equal "eng", r.language_obj.iso_639_3

    # from language_str only with no language_code
    r = ResultItem.new(:title => "something", :language_str => "English")
    assert_present r.language_obj
    assert_equal "eng", r.language_obj.iso_639_3

    # neither is nil with no raise
    r = ResultItem.new(:title => "something")
    assert_nil r.language_obj    
  end

  
  def test_bad_language_code
    r = ResultItem.new(:title => "something", :language_code => "not_valid")
    
    assert_equal "not_valid", r.language_code
    assert_nil r.language_str
  end
  
end
