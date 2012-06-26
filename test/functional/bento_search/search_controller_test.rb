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
    
    test "non-existent engine" do
      get :search, {:engine_id => "not_existing", :query => "my search"}
      
      assert_response 404
    end
    
    test "custom before filter" do
      # Okay, we're going to do a weird thing with a custom controller subclass
      # we can add a custom before filter like a local app might. 
      #
      # SUPER HACKY, but I dunno what else to do. 
      
      class CustomSearchController < BentoSearch::SearchController
        before_filter :deny_everyone
        
        def deny_everyone
          raise BentoSearch::SearchController::AccessDenied
        end
      end
      

      
      orig_controller = @controller
      
      begin
        Rails.application.routes.draw do
          match "/custom_search" => "bento_search/search_controller_test/custom_search#search"
        end
        @controller = CustomSearchController.new
        
        get :search, {:engine_id => "mock", :query => "my search"}
        
        assert_response 403
      ensure
        @controller = orig_controller
        Rails.application.reload_routes!
      end
      
    end
    
    
        
    
  end
end
