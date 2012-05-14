require 'test_helper'



class SearchEngineTest < ActiveSupport::TestCase
  
  def setup
    @dummy_class = Class.new do
      include BentoSearch::SearchEngine
    end
  end
  

    test "takes configuration" do
      conf = Confstruct::Configuration.new( :foo => "foo", :bar => "bar" )
      engine = @dummy_class.new(conf)
      
      assert_not_nil engine.configuration
      assert_equal engine.configuration.foo, "foo"
      assert_equal engine.configuration.bar, "bar"      
    end


end
