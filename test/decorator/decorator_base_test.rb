require 'test_helper'

# Need ActionView so we have a rails view_context available
# at `view` to test with. 
class DecoratorBaseTest < ActionView::TestCase
  class Base
    def foo
      "foo"
    end
    
    def bar
      "bar"
    end
  end
  
  class SpecificDecorator < BentoSearch::DecoratorBase
    def foo
      "Extra #{super}"
    end
    
    def new_method
      "new_method"
    end
    
    def make_br_with_helper
      _h.tag("br")
    end    
    
    def can_html_escape
      # html_escape provided for us by DecoratorBase, because
      # _h.html_escape doesn't work cause Rails is weird and makes
      # it private. 
      html_escape("<foo>")
    end
  end
  
  
  def setup
    @base = Base.new
    @decorated = SpecificDecorator.new(@base, view )
  end
  
  def test_pass_through_methods    
    assert_equal "bar", @decorated.bar
  end
  
  def test_decorator_can_add_method
    assert_equal "new_method", @decorated.new_method
  end
  
  def test_override_with_super
    assert_equal "Extra foo", @decorated.foo
  end
  
        
  def test_can_access_view_context_method
    assert_equal tag("br"), @decorated.make_br_with_helper
  end  
  
  def test_can_html_escape
    # weird workaround needed in implementation for html_escape
    # being defined as private for some reason. 
    assert_equal "&lt;foo&gt;", @decorated.can_html_escape
  end
  
    
  def test_decorated_base
    assert_kind_of Base, @decorated.send("_base")
    assert_equal "foo", @decorated.send("_base").foo
  end
  
end
