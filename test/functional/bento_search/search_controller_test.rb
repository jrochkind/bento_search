require 'test_helper'

module BentoSearch
  class SearchControllerTest < ActionController::TestCase
    def setup
      BentoSearch.register_engine("mock") do |config|
        config.engine = "MockEngine"
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
    
  end
end
