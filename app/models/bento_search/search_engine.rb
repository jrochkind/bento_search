require 'active_support/concern'
require 'active_support/core_ext/module/delegation'
require 'confstruct'


module BentoSearch
  # Module mix-in for bento_search search engines. 
  #
  # ==Using a SearchEngine 
  #
  # * init/config
  # * search
  #   * pagination, with max per_page
  #   * search fields, with semantics. ask for supported search fields. 
  #
  # == Implementing a SearchEngine
  #
  # `include BentoSearch::SearchEngine`
  #
  #  a SearchEngine's state should not be search-specific, but
  #  is configuration specific. Don't store anything specific
  #  to a specific search in iVars. 
  #
  #  Do implement `#search(*args)`
  # 
  #  Do use HTTPClient, if possible, for http searches, 
  #  using a class-level HTTPClient to maintain persistent connections. 
  #
  #  Other options:
  #  * implement a class-level `self.required_configuration' returning
  #    an array of config keys or dot keypaths, and it'll raise on init
  #    if those config's weren't supplied. 
  #  * max per page
  #  * search fields
  #
  module SearchEngine
    extend ActiveSupport::Concern
    
    included do
      attr_accessor :configuration      
    end
    
    # If specific SearchEngine calls initialize, you want to call super
    # handles configuration loading, mostly. Argument is a
    # Confstruct::Configuration. 
    def initialize(aConfiguration = Confstruct::Configuration.new)
      self.configuration = aConfiguration
      # check for required keys
      
      if self.class.respond_to?(:required_configuration)
        self.class.required_configuration.each do |required_key|
          if self.configuration.lookup!(required_key, "**NOT_FOUND**") == "**NOT_FOUND**"
            raise ArgumentError.new("#{self.class.name} requires configuration key #{required_key}")
          end
        end
      end
      
    end
    
    # Calls individual engine #search_implementation.
    # first normalizes arguments, also adds on standard metadata
    # to results. 
    def search(*arguments)
      start_t = Time.now
      
      arguments = parse_search_arguments(*arguments)

      results = search_implementation(arguments)
      
      results.start = arguments[:start] || 0
      results.per_page = arguments[:per_page] || 
        (self.class.respond_to?(:default_per_page) ? 
          self.class.default_per_page :
          10
        )
      
      results.timing = (Time.now - start_t)
        
      return results
    end
        
    protected
    def parse_search_arguments(*orig_arguments)
      arguments = {}
      
      # Two-arg style to one hash, if present
      if (orig_arguments.length > 1 ||
          (orig_arguments.length == 1 && ! orig_arguments.first.kind_of?(Hash)))
        arguments[:query] = orig_arguments.delete_at(0)      
      end

      arguments.merge!(orig_arguments.first)  if orig_arguments.length > 0
      
      
      # allow strings for pagination (like from url query), change to
      # int please. 
      [:page, :per_page, :start].each do |key|
        arguments.delete(key) if arguments[key].blank?
        arguments[key] = arguments[key].to_i if arguments[key]
      end   
      
      # illegal arguments
      if (arguments[:start] || arguments[:page]) && ! arguments[:per_page]
        raise ArgumentError.new("Must supply :per_page if supplying :start or :page")
      end
      if (arguments[:start] && arguments[:page])
        raise ArgumentError.new("Can't supply both :page and :start")
      end
      if ( arguments[:per_page] && 
           self.class.respond_to?(:max_per_page) && 
           arguments[:per_page] > self.class.max_per_page)
        raise ArgumentError.new("#{arguments[:per_page]} is more than maximum :per_page of #{self.class.max_per_page} for #{self.class}")
      end
   
      
      # Normalize :page to :start
      if arguments[:page]
        arguments[:start] = (arguments[:page] - 1) * arguments[:per_page]
        arguments.delete(:page)
      end
      
      # translate semantic_search_field to search_field, or raise if
      # can't. 
      if semantic = arguments.delete(:semantic_search_field)
        mapped = self.class.semantic_search_map[semantic]
        unless mapped
          raise ArgumentError.new("#{self.class.name} does not know about :semantic_search_field #{semantic}")
        end
        arguments[:search_field] = mapped
      end
              
      return arguments
    end
    
    module ClassMethods
      # Returns list of string internal search_field's that can
      # be supplied to search(:search_field => x)
      def search_keys
        return [] unless respond_to? :search_field_definitions
        return search_field_definitions.keys
      end
      
      # Returns list of symbol semantic_search_field that can be
      # supplied to search(:semantic_search_field => x)
      def semantic_search_keys  
        semantic_search_map.keys
      end
      
      # returns a hash keyed by semantic search field symbol,
      # value string internal search field key. 
      def semantic_search_map
        return {} unless respond_to? :search_field_definitions
        
        # Hash[] conveniently takes an array of k-v pairs. 
        return Hash[
          search_field_definitions.collect do |field, defn|
            [ defn[:semantic], field ] if defn && defn[:semantic]
          end.compact        
        ]
      end
      
    end
    
  end
end
