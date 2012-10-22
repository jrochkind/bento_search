# encoding: UTF-8

require 'nokogiri'

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
        raise ArgumentError.new("Need Results, engine, or registered engine_id as first argument to #bento_search") unless search_arg
        BentoSearch.get_engine(search_arg.to_s)
      end)
      
    end

    if (!results && [:ajax_auto, :ajax_triggered].include?(load_mode))
      raise ArgumentError.new("`:load => :ajax` requires a registered engine with an id") unless engine.configuration.id
      content_tag(:div,
        :class => "bento_search_ajax_wait",
        :"data-bento-search-load" => load_mode.to_s, 
        :"data-bento-ajax-url"    => to_bento_search_url( {:engine_id => engine.configuration.id}.merge(options) )) do
      
      # An initially hidden div with loading msg/spinner that will be shown
      # by js on ajax load
      content_tag("noscript") do
        I18n.t("bento_search.ajax_noscript")
      end +
      content_tag(:div, 
        :class => "bento_search_ajax_loading", 
        :style => "display:none") do
      
          image_tag("bento_search/large_loader.gif", 
            :alt => I18n.translate("bento_search.ajax_loading"),            
          ) 

        end
      end
    else
      results = engine.search(options) unless results

      if results.failed?
        partial = (results.display_configuration.error_partial if results.display_configuration) || "bento_search/search_error"         
        render :partial => partial, :locals => {:results => results}
      elsif results.length > 0   
        partial = (results.display_configuration.item_partial if results.display_configuration) || "bento_search/std_item"        
        render :partial => partial, :collection => results, :as => :item, :locals => {:results => results}
      else
        content_tag(:div, :class=> "bento_search_no_results") do
          partial = (results.display_configuration.no_results_partial if results.display_configuration) || "bento_search/no_results"                   
          render :partial => partial, :locals => {:results => results}
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
  
  # Like rails truncate helper, and taking the same options, but html_safe.
  # 
  # If input string is NOT marked html_safe?, simply passes to rails truncate helper. 
  # If a string IS marked html_safe?, uses nokogiri to parse it, and truncate 
  # actual displayed text to max_length, while keeping html structure valid.
  #
  # Default omission marker is unicode elipsis
  #
  # :length option will also default to 280, what we think is a good
  # length for abstract/snippet display
  def bento_truncate(str, options = {})
    options.reverse_merge!(:omission => "…", :length => 280, :separator => ' ')       
    
    # works for non-html of course, but for html a quick check
    # to avoid expensive nokogiri parse if the whole string, even
    # with tags, is still less than max length. 
    return str if str.length < options[:length]
    
    if str.html_safe? 
      noko = Nokogiri::HTML::DocumentFragment.parse(str)
      BentoSearch::Util.nokogiri_truncate(noko, options[:length], options[:omission], options[:separator]).inner_html.html_safe
    else
      return truncate(str, options)
    end
  end
    

  
  # Prepare a title in an H4, with formats in parens in a <small> (for
  # bootstrap), linked, etc. 
  #
  # This is getting a bit complex for a helper method. Not sure the best
  # way to refactor, into partials and helpers? Presenter methods on
  # on item? Without pollutting helper namespace too much?
  def bento_item_title(item)
    content_tag("h4", :class => "bento_item_title") do
      safe_join([
        link_to_unless( item.link.blank?, item.complete_title, item.link ),
        if item.display_format
          content_tag("small", :class => "bento_item_about") do
            arr = []
            
            arr << content_tag("span", item.display_format, :class => "bento_format") if item.display_format
            arr << content_tag("span", "in #{item.display_language}", :class => "bento_language") if item.display_language
            
            " (".html_safe + safe_join(arr, " ") + ")".html_safe if arr
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
        [I18n.translate(key.to_s, :scope => "bento_search.sort_keys", :default => key.to_s.titleize), key.to_s]
      end        
    ]    
  end
  
  
end
