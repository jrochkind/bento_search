require 'test_helper'



class SearchEngineTest < ActiveSupport::TestCase
  
    def setup
      @dummy_class = Class.new do
        include BentoSearch::SearchEngine
        
        def self.required_configuration
          ["required.key"]
        end
      end
    end
  

    test "takes configuration" do
      conf = Confstruct::Configuration.new( :foo => "foo", :bar => "bar", :required => {:key => "required key"} )
      engine = @dummy_class.new(conf)
      
      assert_not_nil engine.configuration
      assert_equal engine.configuration.foo, "foo"
      assert_equal engine.configuration.bar, "bar"      
    end
    
    test "required configuration keys" do
      conf = Confstruct::Configuration.new( :foo => "foo", :bar => "bar" )
      assert_raise ArgumentError do
        @dummy_class.new(conf)
      end
      
    end

end
