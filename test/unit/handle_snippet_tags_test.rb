require 'test_helper'



class HandleSnippetTagsTest < ActiveSupport::TestCase
  
  def test_basic
    result = BentoSearch::Util.handle_snippet_tags(   
      "one two <x> three four </x> five <x>six</x> seven",
      :start_tag => '<x>',
      :end_tag => '</x>'
      )
    
    assert result.html_safe, "result is html_safe"
    
    
    assert_equal("one two <b class=\"bento_search_highlight\"> three four </b> five <b class=\"bento_search_highlight\">six</b> seven", 
      result)        
  end
  
  def test_strip
    result = BentoSearch::Util.handle_snippet_tags(   
      "one two <x> three four </x> five <x>six</x> seven",
      :start_tag => '<x>',
      :end_tag => '</x>',
      :strip => true
      )
    
    assert_equal "one two  three four  five six seven", result
    assert(! result.html_safe?, "not html safe for strip") 
  end
  
  def test_html_escapes
    result = BentoSearch::Util.handle_snippet_tags(   
      "<one> & two <x>three</x> four",
      :start_tag => '<x>',
      :end_tag => '</x>',     
      )
    
    assert result.html_safe?, "result is html_safe"
    assert_equal "&lt;one&gt; &amp; two <b class=\"bento_search_highlight\">three</b> four", result
  end
  
  def test_html_safe_source
    result = BentoSearch::Util.handle_snippet_tags(   
      "<i>x &amp; y</i> <x>three</x> four",
      :start_tag => '<x>',
      :end_tag => '</x>',
      :html_safe_source => true
      )
    
    assert result.html_safe?, "result is html_safe"
    
    assert_equal "<i>x &amp; y</i> <b class=\"bento_search_highlight\">three</b> four", result
  end
  
  def test_enabled_option
    # enabled=false ignores it entirely
    str  = "one two <x> three four </x> five <x>six</x> seven" 
    result = BentoSearch::Util.handle_snippet_tags(   
      str,
      :start_tag => '<x>',
      :end_tag => '</x>',
      :enabled => false
      )
  
    assert ! result.html_safe?, "result is not html safe"
    assert_equal str, result
  end
  
end
