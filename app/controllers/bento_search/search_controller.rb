module BentoSearch
  # This is a controller that provides stand-alone search results
  # for registered engines. Right now, this is only for automatic
  # AJAX delayed loading. In the future it may be used for atom results,
  # or other such.
  #
  # You need to make sure to include routing for this controller in your
  # app to use it, for instance with `BentoSearch::Routes.new(self).draw`
  # in your ./config/routes.rb
  #
  # # Authorization Issues
  #
  # You may have some engines which should not be publically searchable,
  # they should only be searchable by certain auth'd users. This controller
  # could accidentally provide a non-protected endpoint to get results if
  # nothing were done to prevent it.
  #
  # Only engines which have a :allow_routable_results => true key
  # in their config will be served by this controller.
  #
  # If you need routable results on an engine which ALSO needs to
  # be protected by auth, you can add your own Rails before_action
  # to provide auth. Say, in an initializer in your app:
  #
  #     SearchController.before_action do |controller|
  #       unless controller.current_user
  #          raise BentoSearch::SearchController::AccessDenied
  #       end
  #     end
  #
  # We may provide fancier/nicer API for this in the future, if there's
  # demand.
  #
  # Similarly, while by default all query params sent to the controller
  # are passed on to the engine, you can add your own before_action
  # to filter them, use `engine_args=`. For instance, if the params
  # need to depend on the user's logged in state or other aspects of
  # request, or need to be filtered for security.
  #
  #    SearchController.before_action do |controller|
  #       controller.engine_args = my_custom_args(controller.params, controller.engine)
  #    end
  #
  # Lastly, this is a pretty bare bones implementation -- feel
  # free to sub-class it, or even just copy-and-paste it into
  # your own implementation, and provide your own routing. (May need
  # to make it easier or clearer how to do this? Let us know.)
  class SearchController < BentoSearchController
    class AccessDenied < BentoSearch::Error ; end

    attr_writer :engine_args


    rescue_from AccessDenied, :with => :deny_access
    rescue_from NoSuchEngine, :with => :render_404

    # returns partial HTML results, suitable for
    # AJAX to insert into DOM.
    # arguments for engine.search are taken from URI request params, whitelisted
    def search
      unless engine.configuration.allow_routable_results == true
        raise AccessDenied.new("engine needs to be registered with :allow_routable_results => true")
      end

      @results         = engine.search engine_args
      # template name of a partial with 'yield' to use to wrap the results
      @partial_wrapper = @results.display_configuration.lookup!("ajax.wrapper_template")

      # partial HTML results
      render "bento_search/search/search", :layout => false
    end

    protected

    def engine
      @engine ||= BentoSearch.get_engine(params[:engine_id])
    end

    def engine_args
      if @engine_args
        @engine_args
      else
        safe_search_args(engine, params)
      end
    end

    def safe_search_args(engine, params)
      all_hash = params.respond_to?(:to_unsafe_hash) ? params.to_unsafe_hash : params.to_hash
      all_hash.symbolize_keys.slice( *engine.public_settable_search_args )
    end

    def deny_access(exception)
      render :plain => exception.message, :status => 403
    end

    def render_404(exception)
      render :plain => exception.message, :status => 404
    end


  end
end
