require 'test_helper'

class LinkTest < ActionView::TestCase
  
  def test_link_target
    link = BentoSearch::Link.new(:label => "foo", :url => "/foo", :target => "custom_target")
    
    render "bento_search/link", :link => link
    
    assert_select("a[target=custom_target]")
  end
  
  def test_link_no_target
    link = BentoSearch::Link.new(:label => "foo", :url => "/foo")
    
    render "bento_search/link", :link => link
    
    assert_select("a[target]", :count => 0)
  end
  
end
