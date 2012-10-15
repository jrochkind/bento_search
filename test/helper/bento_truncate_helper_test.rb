# encoding: UTF-8

require 'test_helper'

# this seems to work? Rails view testing is a mess. 
require 'sprockets/helpers/rails_helper'

class BentoSearchHelperTest < ActionView::TestCase
  include BentoSearchHelper
    
  
  def test_truncate_basic
    # Basic test
    output = bento_truncate("12345678901234567890", :length => 10)
    assert_equal "123456789…", output
  end
  
  def test_truncate_tags    
    # With tags
    html_input = "123456<p><b>78901234567</b>890</p>".html_safe
    html_output = bento_truncate(html_input, :length => 10)    
    assert html_output.html_safe?, "truncated html_safe? is still html_safe?"
    assert_equal "123456<p><b>789…</b></p>", html_output
  end
  
  def test_truncate_tag_boundary    
    # With break on tag boundary. Yes, there's an error not accounting
    # for length of omission marker in this particular edge case,
    # hard to fix, good enough for now. 
    html_input = "<p>1234567890<b>123456</b>7890</p>".html_safe
    html_output = bento_truncate(html_input, :length => 10)
    assert_equal "<p>1234567890…</p>", html_output    
  end
  
  def test_truncate_boundary_edge_case
    html_input = "12345<p>6789<b>0123456</b>7890</p>".html_safe
    html_output = bento_truncate(html_input, :length => 10)
    # yeah, weird elipses in <b> of their own, so it goes. 
    assert_equal "12345<p>6789<b>…</b></p>", html_output
  end
  
  def test_truncate_another_edge_case
    html_input = "12345<p>67890<b>123456</b>7890</p>".html_safe
    html_output = bento_truncate(html_input, :length => 10)
    assert_equal "12345<p>67890…</p>", html_output
  end
  
  def test_truncate_html_with_seperator
    html_input = "12345<p>67 901234<b></p>".html_safe
    html_output = bento_truncate(html_input, :length => 10, :seperator => ' ')
    assert_equal "12345<p>67…</p>", html_output
  end
  
  def test_truncate_html_with_seperator_unavailable
    html_input = "12345<p>678901234<b></p>".html_safe
    html_output = bento_truncate(html_input, :length => 10, :seperator => ' ')
    assert_equal "12345<p>6789…</p>", html_output
  end
  
  def test_truncate_html_with_boundary_seperator
    # known edge case we dont' handle, sorry. If this test
    # fails, that could be a good thing if you've fixed the edge case!
    html_input = "12345<p>6 8<b>90123456</b>7890</p>".html_safe
    html_output = bento_truncate(html_input, :length => 10, :seperator => ' ')
    assert_equal "12345<p>6 8<b>9…</b></p>", html_output
  end
   
    

  
end
