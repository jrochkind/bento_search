require 'test_helper'

module BentoSearch
  class SearchControllerTest < ActionController::TestCase
    def setup
      BentoSearch.register_engine("mock") do |config|
        config.engine = "MockEngine"
        config.allow_routable_results = true
      end

      BentoSearch.register_engine("failed_response") do |config|
        config.engine = "MockEngine"
        config.allow_routable_results = true
        config.error = {:message => "faked error"}
      end

      BentoSearch.register_engine("not_routable") do |config|
        config.engine = "MockEngine"
        # no allow_routable_results
      end

      BentoSearch.register_engine("with_layout_config") do |config|
        config.engine = "MockEngine"

        config.allow_routable_results = true

        config.for_display do |display|
          display.ajax do |ajax|
            ajax.wrapper_template = "bento_search/wrap_with_count"
          end
        end
      end
    end

    def teardown
      BentoSearch.reset_engine_registrations!
    end


    test "search" do
      get :search, {:engine_id => "mock", :query => "my search"}
      assert_response :success
      assert_not_nil assigns(:results)

      assert_template "bento_search/search/search"

      # meta tag with count
      meta_tag = assert_select("meta[itemprop=total_items][content]", :count => 1 )
      assert_match(/^\d+$/, meta_tag.attribute("content").text)
    end

    test "failed search" do
      get :search, {:engine_id => "failed_response", :query => "my search"}

      # should this really be a success? Yes, I think so, we don't
      # want to stop ajax from getting it, it'll just have an error
      # message in the HTML. Should it maybe have an html5 meta microdata
      # warning?
      assert_response :success

      assert_template "bento_search/search/search"
      assert_template "bento_search/_search_error"

      assert_select("meta[itemprop=total_items]", :count => 0)
    end





    test "custom layout config" do
      get :search, {:engine_id => "with_layout_config", :query => "my search"}

      assert_response :success

      assert_not_nil assigns(:partial_wrapper)

      assert_template "bento_search/_wrap_with_count"
      assert_template "bento_search/search/search"
    end

    test "non-routable engine" do
      get :search, {:engine_id => "not_routable", :query => "my search"}

      assert_response 403
    end

    test "non-existent engine" do
      get :search, {:engine_id => "not_existing", :query => "my search"}

      assert_response 404
    end


    test "respects public_settable_search_args" do
      get :search, {:engine_id => "mock",
          'query' => "query", 'sort' => "sort", 'per_page' => "15",
      'page' => "6", 'search_field' => "title", 'not_allowed' => "not allowed"}


      search_args = assigns[:engine].last_args

      [:query, :sort, :per_page, :page, :search_field].each do |allowed_key|
        assert search_args.has_key?(allowed_key)
      end
      assert ! search_args.has_key?(:not_allowed)
      assert ! search_args.has_key?("not_allowed")
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
          get "/custom_search" => "bento_search/search_controller_test/custom_search#search"
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
