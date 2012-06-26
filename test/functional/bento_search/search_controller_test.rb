require 'test_helper'

module BentoSearch
  class SearchControllerTest < ActionController::TestCase
    def setup
      BentoSearch.register_engine("mock") do |config|
        config.engine = "MockEngine"
        config.allow_routable_results = true
      end
      
      BentoSearch.register_engine("not_routable") do |config|
        config.engine = "MockEngine"
        # no allow_routable_results
      end
      
    end
    
    def teardown     
      BentoSearch.reset_engine_registrations!
    end
    
    
    test "search" do
      get :search, {:engine_id => "mock", :query => "my search"}
      assert_response :success
      assert_not_nil assigns(:results)
      
      assert_template "bento_search/search"
    end
    
    test "non-routable engine" do
      get :search, {:engine_id => "not_routable", :query => "my search"}
      
      assert_response 403
    end
    

        
    
  end
end
