# Rails helper module provided by BentoSearch meant to be included
# in host app's helpers. 
module BentoSearchHelper
  
  # Renders bento search results on page, or an AJAX loader, etc, as appropriate.
  # Pass in:
  #   * BentoSearch::SearchResults => will render
  #   * an instantiated BentoSearch::SearchEngine => Will do search and render
  #   * an id that a search engine was registered under with 
  #     BentoSearch.register_engine => will do search and render. 
  #
  #  Second arg options hash includes options for bento_search helper,
  #  as well as other options pased on to BentoSearch::Engine.search(options)
  #
  # == Options
  #
  #  load: :ajax_auto, :immediate.  :ajax_auto will put a spinner up there,
  #        and load actual results via AJAX request. :immediate preloads
  #        results. 
  #
  # == Examples
  #
  #     bento_results( results_obj )
  #     bento_results( engine_obj, :query => "cancer")
  #     bento_results("google_books", :query => "cancer", :load => :ajax_auto)
  #  
  def bento_search(search, options = {})
    results = search if search.kind_of? BentoSearch::Results
    
    load_mode = options.delete(:load) 
    
    engine = nil
    unless results
      # need to load an engine and do a search, or ajax, etc. 
      engine = (if search.kind_of? BentoSearch::SearchEngine
        search
      else
        BentoSearch.get_engine(search.to_s)
      end)
      
    end

    if (!results && load_mode == :ajax_auto)
      raise ArgumentError.new("`:load => :ajax` requires a registered engine with an id") unless engine.configuration.id
      content_tag(:div, :class => "bento_search_ajax_wait",
        :"data-bento-ajax-url" => to_bento_search_url( {:engine_id => engine.configuration.id}.merge(options) )) do
        content_tag("noscript") do
          "Can not load results without javascript"
        end
      end
    else
      results = engine.search(options) unless results
      render :partial => "bento_search/std_item", :collection => results    
    end                          
  end
    
    
  
end
