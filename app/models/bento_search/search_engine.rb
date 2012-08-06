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
  # == Standard config
  #  * item_decorators : Array of Modules that will be decorated. See Decorators section. 
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
  #  Some engines support `:auth => true` for elevated access to affiliated
  #  users. 
  #
  module SearchEngine
    DefaultPerPage = 10
    
    extend ActiveSupport::Concern
    
    include Capabilities
    
    included do
      attr_accessor :configuration      
    end
    
    # If specific SearchEngine calls initialize, you want to call super
    # handles configuration loading, mostly. Argument is a
    # Confstruct::Configuration or Hash. 
    def initialize(aConfiguration = Confstruct::Configuration.new)
      # init, from copy of default, or new      
      if self.class.default_configuration
        self.configuration = Confstruct::Configuration.new(self.class.default_configuration)
      else
        self.configuration = Confstruct::Configuration.new
      end
      # merge in current instance config
      self.configuration.configure ( aConfiguration )
      
      # global defaults?
      self.configuration[:item_decorators] ||= []
            
      # check for required keys
      if self.class.required_configuration
        self.class.required_configuration.each do |required_key|          
          if self.configuration.lookup!(required_key.to_s, "**NOT_FOUND**") == "**NOT_FOUND**"
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
      
      arguments = normalized_search_arguments(*arguments)

      results = search_implementation(arguments)
      
      decorate(results)      
      
      # standard result metadata
      results.start = arguments[:start] || 0
      results.per_page = arguments[:per_page]
      
      results.search_args   = arguments
      results.engine_id     = configuration.id
      
      results.timing = (Time.now - start_t)
        
      return results
    end
        

    
    def normalized_search_arguments(*orig_arguments)
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
      arguments[:per_page] ||= DefaultPerPage
      
      # illegal arguments      
      if (arguments[:start] && arguments[:page])
        raise ArgumentError.new("Can't supply both :page and :start")
      end
      if ( arguments[:per_page] && 
           self.max_per_page && 
           arguments[:per_page] > self.max_per_page)
        raise ArgumentError.new("#{arguments[:per_page]} is more than maximum :per_page of #{self.max_per_page} for #{self.class}")
      end
   
      
      # Normalize :page to :start, and vice versa
      if arguments[:page]
        arguments[:start] = (arguments[:page] - 1) * arguments[:per_page]
      elsif arguments[:start]
        arguments[:page] = (arguments[:start] / arguments[:per_page]) + 1
      end
      
      # normalize :sort from possibly symbol to string
      # TODO: raise if unrecognized sort key?
      if arguments[:sort]
        arguments[:sort] = arguments[:sort].to_s
      end
      
      # translate semantic_search_field to search_field, or raise if
      # can't. 
      if (semantic = arguments.delete(:semantic_search_field)) && ! semantic.blank?
        
        mapped = self.semantic_search_map[semantic.to_s]
        unless mapped
          raise ArgumentError.new("#{self.class.name} does not know about :semantic_search_field #{semantic}")
        end
        arguments[:search_field] = mapped
      end
              
      return arguments
    end
    alias_method :parse_search_arguments, :normalized_search_arguments
    
    

   
    
    protected
    
    # Extend each result with each specified decorator module
    def decorate(results)      
      results.each do |result|
        configuration.item_decorators.each do |decorator|
          result.extend decorator
        end
      end
    end
    
    
    module ClassMethods
      
      # If support fielded search, over-ride to specify fields
      # supported. Returns a hash, key is engine-specific internal
      # search field, value is nil or a hash of metadata about
      # the search field, including semantic mapping. 
      #
      # def search_field_definitions
      #  { "intitle" => {:semantic => :title}}
      # end
      def search_field_definitions
        {}
      end
      
            
      # Returns list of string internal search_field's that can
      # be supplied to search(:search_field => x)
      def search_keys        
        return search_field_definitions.keys
      end
      
      
      
      # Over-ride returning a hash or Confstruct with 
      # any configuration values you want by default. 
      # actual user-specified config values will be deep-merged
      # into the defaults. 
      def default_configuration
      end
      
      # Over-ride returning an array of symbols for required
      # configuration keys.
      def required_configuration
      end
      
    end
    
  end
end
