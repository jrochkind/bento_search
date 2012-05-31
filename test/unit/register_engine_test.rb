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
  
  
  test "raises on unregistered engine access" do
    assert_raise(ArgumentError) { BentoSearch.get_engine("not_registered")}
  end
  
end
  
