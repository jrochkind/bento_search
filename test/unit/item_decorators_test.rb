require 'test_helper'

class ItemDecoratorsTest < ActiveSupport::TestCase
  MockEngine = BentoSearch::MockEngine
  

  ################
  # ABove here, old style decorators on their way out. Below, new:
  ###########
  
  test "decorator specified in configuration" do
    @engine = MockEngine.new(:for_display => {:decorator => "TestDecorator"})
    results = @engine.search("query")
    
    assert_equal "TestDecorator", results.first.decorator
  end
    

  
end
