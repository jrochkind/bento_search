require 'test_helper'



class SearchEngineTest < ActiveSupport::TestCase
  
    def setup
      @dummy_class = Class.new do
        include BentoSearch::SearchEngine
        
        def self.required_configuration
          ["required.key"]
        end
        
        def search_implementation(arguments)
          #no-op for now
          BentoSearch::Results.new
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
    
    test "merges default configuration" do
      @dummy_class = Class.new do
        include BentoSearch::SearchEngine
        def self.default_configuration
          { :one => "default",
            :two => "default",
            :array => [:a, :b, :c],
            :nested => {:one => "default", :two => "default"}
          }
        end
      end
      
      engine = @dummy_class.new( :two => "new", :array => ["one", "two"], :nested => {:two => "new"}, :required => {:key => "required key"} )
      
      assert_kind_of Confstruct::Configuration, engine.configuration
      assert_equal "default"      , engine.configuration.one
      assert_equal "new"          , engine.configuration.two
      assert_equal "default"      , engine.configuration.nested.one
      assert_equal "new"          , engine.configuration.nested.two
      assert_equal ["one", "two"] , engine.configuration.array      
    end
    
    test "no default configuration" do
      @dummy_class = Class.new do
        include BentoSearch::SearchEngine
      end
      
      engine = @dummy_class.new( :one => "one" )
      
      assert_kind_of Confstruct::Configuration, engine.configuration
      assert_equal "one", engine.configuration.one
    end
      

end
