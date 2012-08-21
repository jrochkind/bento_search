require 'test_helper'

class LinkDecoratorsTest < ActiveSupport::TestCase
  MockEngine = BentoSearch::MockEngine
  
  # simple decorator that replaces main link
  module Decorator
    def link
      "http://newlink.com"
    end
    
    def other_links      
      super + [ BentoSearch::Link.new(:label => "One", :url => "http://one.com") ]
    end
  end
    
  setup do
    @engine = MockEngine.new(:item_decorators => [Decorator])
  end
  
  test "decorators" do
    results = @engine.search(:query => "Query")
    
    assert_present results            
    
    results.each do |result|
      assert_kind_of Decorator, result
      
      assert_equal "http://newlink.com", result.link
      
      assert_present result.other_links

      assert_equal "One",             result.other_links.first.label
      assert_equal "http://one.com",  result.other_links.first.url          
    end    
  end
  
  # Is it a good idea to have a decorator that mutates on 'extend'?
  # I'm not sure, I think probably not, but it is possible.
  # Here we'll use it to move an original link to other links
  module MutatingDecorator    
    def self.extended(item)
      orig_link = item.link
      
      item.link = nil
      
      item.other_links << BentoSearch::Link.new(:label => "Some Other", :url => orig_link)      
    end
  end
  
  test "mutating decorator" do
    @engine = MockEngine.new(:item_decorators => [MutatingDecorator], :link => "http://example2.org")
    results = @engine.search("query")
    
    assert_present results
    
    results.each do |result|
      assert_blank result.link
      assert_equal "http://example2.org", result.other_links.first.url  
      assert_equal "Some Other",          result.other_links.first.label
    end
    
  end

    

  
end
