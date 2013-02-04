require 'test_helper'



class RegisterEngineTest < ActiveSupport::TestCase
  class BentoSearch::DummyEngine
    include BentoSearch::SearchEngine
  end
    
  def teardown
    BentoSearch.reset_engine_registrations!
  end
  
  test "can register and retrieve engine" do
    BentoSearch.register_engine("test_engine") do |conf|
      conf.engine = "BentoSearch::DummyEngine"      
      conf.api_key = "dummy"
    end
    
    engine = BentoSearch.get_engine("test_engine")
    
    assert_kind_of BentoSearch::DummyEngine, engine    
    assert_equal "dummy", engine.configuration.api_key
    
  end
  
  test "can register with engine name assumed in BentoSearch::" do
    BentoSearch.register_engine("test_engine") do |conf|
      conf.engine = "DummyEngine"      
      conf.api_key = "dummy"
    end
    
    assert_kind_of BentoSearch::DummyEngine, BentoSearch.get_engine("test_engine")
  end
  
  test "raises for no engine class" do
    assert_raises(ArgumentError) do
      BentoSearch.register_engine("test_engine") do |conf|              
        conf.api_key = "dummy"
      end
    end
  end
  
  
  test "raises on unregistered engine access" do
    assert_raise(BentoSearch::NoSuchEngine) { BentoSearch.get_engine("not_registered")}
  end
  
  test "returns configuration" do
    returned_configuration = BentoSearch.register_engine("test_engine") do |conf|
      conf.engine = "DummyEngine"
      conf.api_key = "dummy"
    end
                
    assert_kind_of Confstruct::Configuration, returned_configuration
  end
  
  test "can take data argument instead of block" do
    BentoSearch.register_engine("test_engine", 
      {:engine => "DummyEngine", :api_key => "dummy"}
    )

    engine = BentoSearch.get_engine("test_engine")
    
    assert_kind_of BentoSearch::DummyEngine, engine    
    assert_equal "dummy", engine.configuration.api_key        
  end
  
  test "block over-rides data argument" do
    args = {:engine => "DummyEngine", :api_key => "dummy", :other_thing => "other_thing"}
    
    BentoSearch.register_engine("test_engine", args) do |conf|
      conf.api_key = "new_api_key"
    end
    
    engine = BentoSearch.get_engine("test_engine")

      
    assert_equal "new_api_key", engine.configuration.api_key
    assert_equal "other_thing", engine.configuration.other_thing
  end
  
  test "use one config as base for another" do
    source_configuration = BentoSearch.register_engine("source_engine") do |conf|
      conf.engine      = "DummyEngine"      
      conf.api_key     = "api_key"
      conf.for_display do |display|
        display.title = "source_title"
      end
    end
    
    BentoSearch.register_engine("derived_engine", source_configuration) do |conf|      
      conf.for_display do |display|
        display.title = "derived_title"
      end
    end
    
    source_engine  = BentoSearch.get_engine("source_engine")
    derived_engine = BentoSearch.get_engine("derived_engine")
    
    assert_equal "api_key",       derived_engine.configuration.api_key
    assert_equal "derived_title", derived_engine.configuration.for_display.title
    
    assert_equal "source_title",  source_engine.configuration.for_display.title
    
  end
  
end
  
