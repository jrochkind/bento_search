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
  def bento_search(search_arg, options = {})
    results = search_arg if search_arg.kind_of? BentoSearch::Results
    
    load_mode = options.delete(:load) 
    
    engine = nil
    unless results
      # need to load an engine and do a search, or ajax, etc. 
      engine = (if search_arg.kind_of? BentoSearch::SearchEngine
        search_arg
      else
        BentoSearch.get_engine(search_arg.to_s)
      end)
      
    end

    if (!results && load_mode == :ajax_auto)
      raise ArgumentError.new("`:load => :ajax` requires a registered engine with an id") unless engine.configuration.id
      content_tag(:div, :class => "bento_search_ajax_wait",
        :"data-bento-ajax-url" => to_bento_search_url( {:engine_id => engine.configuration.id}.merge(options) )) do
        image_tag("bento_search/large_loader.gif", :alt => I18n.translate("bento_search.ajax_loading")) +
        content_tag("noscript") do
          "Can not load results without javascript"
        end
      end
    else
      results = engine.search(options) unless results

      if results.failed?
        render :partial => "bento_search/search_error", :locals => {:results => results}
      elsif results.length > 0      
        render :partial => "bento_search/std_item", :collection => results, :as => :item
      else
        content_tag(:div, :class=> "bento_search_no_results") do
          I18n.translate("bento_search.no_results")
        end
      end
    end                          
  end
    
  
  ##
  # More methods used by bento standard views, namespaced with bento_, sorry
  # no great way to take logic out of views into helper methods without
  # namespacey hack. 
  #
  # You can use these methods in your own custom views, you also should be
  # able to over-ride them (including calling super) in local helpers to
  # change behavior in standard views. 
  #
  ##
  
  def bento_abstract_truncate(str)
    # if it's html safe, we can't truncate it, we don't have an HTML-aware
    # truncation routine right now, that avoids leaving tags open etc. 
    return str if str.html_safe?
    
    truncate(str, :length => 280, :separator => " ")    
  end
  
  # Prepare a title in an H4, with formats in parens in a <small> (for
  # bootstrap), linked, etc. 
  def bento_item_title(item)
    content_tag("h4", :class => "bento_item_title") do
      safe_join([
        link_to_unless( item.link.blank?, item.complete_title, item.link ),
        if item.format.present? || item.format_str.present?
          content_tag("small", :class => "bento_item_about") do
            " (" +
              if item.format_str
                item.format_str
              else
                t(item.format, :scope => [:bento_search, :format], :default => item.format.to_s.titleize)
              end + ")"
          end
        end
      ], '')
    end
  end
  
  # first 3 authors, each in a <span>, using item.author_display, seperated by
  # semi-colons. 
  def bento_item_authors(item)
    parts = []
    
    first_three = item.authors.slice(0,3) 
        
    first_three.each_with_index do |author, index|
      parts << content_tag("span", :class => "bento_item_author") do
          item.author_display(author)
      end
      if (index + 1) < first_three.length
        parts << "; "
      end      
    end
    
    return safe_join(parts, "")
  end
  
  # returns a hash of label => key suitable for passing to rails
  # options_for_select. (Yes, it works backwards from how you'd expect). 
  # Label is looked up using I18n, at bento_search.sort_keys.*
  #
  # If no i18n is found, titleized version of key itself is used as somewhat
  # reasonable default. 
  def bento_sort_hash_for(engine)
    Hash[ 
      engine.sort_definitions.keys.collect do |key|
        [I18n.translate(key, :scope => "bento_search.sort_keys", :default => key.titleize), key]
      end        
    ]    
  end
  
  
end
