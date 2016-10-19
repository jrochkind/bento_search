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
  # Partial used for display can be configured on engine with
  #   * for_display.error_partial => gets `results` local
  #   * for_display.no_results_partial => gets `results` local
  #   * for_display.item_partial => `:collection => results, :as => :item, :locals => {:results => results}`
  #   * for_display.ajax_loading_partial => local `engine`
  #
  # If not specified for a particular engine, the partials listed in BentoSearch.defaults will be used.
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

          partial = (engine.configuration.for_display.ajax_loading_partial if engine.configuration.for_display) || BentoSearch.defaults.ajax_loading_partial
          render :partial => partial, locals: { engine: engine }
        end
    else
      results = engine.search(options) unless results

      if results.failed?
        partial = (results.display_configuration.error_partial if results.display_configuration) || BentoSearch.defaults.error_partial
        render :partial => partial, :locals => {:results => results}
      elsif results.length > 0
        partial = (results.display_configuration.item_partial if results.display_configuration) || BentoSearch.defaults.item_partial
        render :partial => partial, :collection => results, :as => :item, :locals => {:results => results}
      else
        content_tag(:div, :class=> "bento_search_no_results") do
          partial = (results.display_configuration.no_results_partial if results.display_configuration) || BentoSearch.defaults.no_results_partial
          render :partial => partial, :locals => {:results => results}
        end
      end
    end
  end

  # Wrap a ResultItem in a decorator! For now hard-coded to
  # BentoSearch::StandardDecorator
  def bento_decorate(result_item)
    # in a helper method, 'self' is a view_context already I think?
    decorated = BentoSearch::DecoratorBase.decorate(result_item, self)
    yield(decorated) if block_given?
    return decorated
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
    return str if str.nil? || str.empty?

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



  # Deprecated, made more sense to put this in a partial. Just
  # call partial directly:
  #  <%= render :partial => "bento_search/item_title", :object => item, :as => 'item'  %>
  def bento_item_title(item)
    render :partial => "bento_search/item_title", :object => item, :as => 'item'
  end
  deprecate :bento_item_title

  # pass in 0-based rails current collection counter and a BentoSearch::Results,
  # calculates a user-displayable result set index label.
  #
  # Only non-trivial thing is both inputs are allowed to be nil; if either
  # is nil, nil is returned.
  def bento_item_counter(counter, results)
    return nil if counter.nil? || results.nil? || results.start.nil?

    return counter + results.start + 1
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

  # Returns a hash of label => key suitable for passing to rails
  # options_for_select. ONLY includes fields with :semantics set at
  # present. Key will be _semantic_ key name.
  # For engine-specific fields, you're on you're own, sorry!
  #
  # If first arg is an engine instance, will
  # be search fields supported by that engine. If first arg is nil,
  # will be any field in our i18n lists for search fields.
  #
  # Can pass in options :only or :except to customize list. Values
  # in :only and :except will match on internal field names OR
  # semantic field names (hopefully this convenience ambiguity
  # won't cause problems)
  #
  # eg:
  #     <%= select_tag 'search_field', options_for_select(bento_field_hash_for(@engine), params[:search_field]) %>
  def bento_field_hash_for(engine, options = {})
    if engine.nil?
      hash = I18n.t("bento_search.search_fields").invert
    else
      hash = Hash[ engine.search_field_definitions.collect do |k, defn|
        if defn[:semantic] && (label = I18n.t(defn[:semantic], :scope => "bento_search.search_fields", :default => defn[:semantic].to_s.titlecase ))
          [label,  defn[:semantic].to_s]
        end
      end.compact]
    end

    # :only/:except
    if options[:only]
      keys = [options[:only]].flatten.collect(&:to_s)
      hash.delete_if {|key, value|  ! keys.include?(value) }
    end

    if options[:except]
      keys = [options[:except]].flatten.collect(&:to_s)
      hash.delete_if {|key, value|  keys.include?(value) }
    end

    return hash
  end


end
