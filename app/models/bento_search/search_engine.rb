require 'active_support/concern'
require 'active_support/core_ext/module/delegation'
require 'confstruct'

# just so we can catch their exceptions:
require 'httpclient'
require 'multi_json'
require 'nokogiri'

module BentoSearch
  # Module mix-in for bento_search search engines. 
  #
  # ==Using a SearchEngine 
  #
  # See a whole bunch more examples in the project README.
  #
  # You can initialize a search engine with configuration (some engines
  # have required configuration):
  #
  #      engine = SomeSearchEngine.new(:config_key => 'foo')
  #
  # Or, it can be convenient (and is required for some features) to store
  # a search engine with configuration in a global registry:
  #
  #      BentoSearch.register_engine("some_searcher") do |config|
  #         config.engine = "SomeSearchEngine"
  #         config.config_key = "foo"
  #      end
  #      # instantiates a new engine with registered config:
  #      engine = BentoSearch.get_engine("some_searcher")
  #
  #  You can then use the #search method, which returns an instance of
  #  of BentoSearch::Results
  #
  #  results = engine.search("query")
  # 
  #  See more docs under #search, as well as project README.  
  #
  # == Standard configuration variables. 
  # 
  # Some engines require their own engine-specific configuration for api keys
  # and such, and offer their own engine-specific configuration for engine-specific
  # features. 
  #
  # An additional semi-standard configuration variable, some engines take
  # an `:auth => true` to tell the engine to assume that all access is by
  # authenticated local users who should be given elevated access to results.  
  #
  # Additional standard configuration keys that are implemented by the bento_search
  # framework:
  #
  #  [item_decorators]
  #      Array of Modules (or strings specifying modules, helpful to keep
  #      config serializable) that will be decorated on to each individual search
  #      BentoSearch::ResultItem. These can be used to, via configuration, change
  #      the links associated with items, change certain item behaviors, or massage
  #      item metadata. (Needs more documentation). 
  #      
  #
  # == Implementing a SearchEngine
  #
  # Implmeneting a new SearchEngine is relatively straightforward -- you are
  # generally only responsible for the parts specific to your search engine:
  # receiving a query, making a call to the external search engine, and
  # translating it's result to standard a BentoSearch::Results full of
  # BentoSearch::ResultItems. 
  #
  # Start out by simply including the search engine module:
  #
  # class MyEngine
  #   include BentoSearch::SearchEngine
  # end
  #
  # Next, at a minimum, you need to implement a #search_implementation
  # method, which takes a _normalized_ hash of search instructions as input
  # (see documentation at #normalized_search_arguments), and returns
  # BentoSearch::Results item.
  #
  # The Results object should have #total_items set with total hitcount, and
  # contain BentoSearch::ResultItem objects for each hit in the current page. 
  # See individual class documentation for more info. 
  #
  # That's about the extent of your responsibilities. If the search failed
  # for some reason due to an error, you should return a Results object
  # with it's #error object set, so it will be `failed?`.  The framework
  # will take care of this for you for certain uncaught exceptions you allow
  # to rise out of #search_implementation (timeouts, HTTPClient timeouts,
  # nokogiri and MultiJson parse errors). 
  #
  # A SearchEngine object can be re-used for multiple searches, possibly
  # under concurrent multi-threading. Do not store search-specific state
  # in the search object. but you can store configuration-specific state there
  # of course. 
  # 
  # Recommend use of HTTPClient, if possible, for http searches. Especially
  # using a class-level HTTPClient instance, to re-use persistent http
  # connections accross searches (can be esp important if you need to contact
  # external search api via https/ssl).
  #
  # If you have required configuration keys, you can register that with 
  # class-level required_configuration_keys method. 
  #
  # You can also advertise max per-page value by overriding max_per_page. 
  #
  # If you support fielded searching, you should over-ride 
  # #search_field_definitions; if you support sorting, you should
  # override #sort_definitions. See BentoSearch::SearchEngine::Capabilities
  # module for documentation. 
  # 
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
            
      # check for required keys -- have to be present, and not nil
      if self.class.required_configuration
        self.class.required_configuration.each do |required_key|          
          if ["**NOT_FOUND**", nil].include? self.configuration.lookup!(required_key.to_s, "**NOT_FOUND**")
            raise ArgumentError.new("#{self.class.name} requires configuration key #{required_key}")
          end
        end
      end
      
    end
    
    
    # Method used to actually get results from a search engine.  
    #
    # When implementing a search engine, you do not override this #search
    # method, but instead override #search_implementation. #search will
    # call your specific #search_implementation, first normalizing the query
    # arguments, and then normalizing and adding standard metadata to your return value.      
    #
    #  Most engines support pagination, sorting, and searching in a specific
    #  field. 
    #
    #      # 1-based page index
    #      engine.search("query", :per_page => 20, :page => 5)
    #      # or use 0-based per-record index, engines that don't
    #      # support this will round to nearest page. 
    #      engine.search("query", :start => 20)
    #
    #  You can ask an engine what search fields it supports with engine.search_keys
    #      engine.search("query", :search_field => "engine_search_field_name")
    #
    #  There are also normalized 'semantic' names you can use accross engines
    #  (if they support them): :title, :author, :subject, maybe more. 
    #
    #      engine.search("query", :semantic_search_field => :title)
    #
    #  Ask an engine what semantic field names it supports with `engine.semantic_search_keys`
    #
    #  Ask an engine what sort fields it supports with `engine.sort_keys`. See
    #  list of standard sort keys in I18n file at ./config/locales/en.yml, in
    #  `en.bento_search.sort_keys`. 
    #
    #      engine.search("query", :sort => "some_sort_key")
    #
    #  Some engines support additional arguments to 'search', see individual
    #  engine documentation. For instance, some engines support `:auth => true`
    #  to give the user elevated search privileges when you have an authenticated
    #  local user. 
    #
    # Query as first arg is just a convenience, you can also use a single hash
    # argument. 
    #
    #      engine.search(:query => "query", :per_page => 20, :page => 4)
    #
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
    rescue *auto_rescue_exceptions => e
      # Uncaught exception, log and turn into failed Results object. We
      # only catch certain types of exceptions, or it makes dev really
      # confusing eating exceptions. This is intentionally a convenience
      # to allow search engine implementations to just raise the exception
      # and we'll turn it into a proper error. 
      cleaned_backtrace = Rails.backtrace_cleaner.clean(e.backtrace)
      log_msg = "BentoSearch::SearchEngine failed results: #{e.inspect}\n    #{cleaned_backtrace.join("\n    ")}"
      Rails.logger.error log_msg
      
      failed = BentoSearch::Results.new
      failed.error ||= {}
      failed.error[:exception] = e
      return failed
    end
        

    # Take the arguments passed into #search, which can be flexibly given
    # in several ways, and normalize to an expected single hash that
    # will be passed to an engine's #search_implementation. The output
    # of this method is a single hash, and is what a #search_implementation
    # can expect to receive as an argument, with keys: 
    #
    # [:query]        the query
    # [:per_page]     will _always_ be present, using the default per_page if
    #                 none given by caller
    # [:start, :page] both :start and :page will _always_ be present, regardless
    #                 of which the caller used. They will both be integers, even if strings passed in.
    # [:search_field] A search field from the engine's #search_field_definitions, as string.  
    #                 Even if the caller used :semantic_search_field, it'll be normalized
    #                 to the actual local search_field key on output. 
    # [:sort]         Sort key. 
    #
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
    # configuration.item_decorators is an array of either Module constants,
    # or strings specifying module constants. 
    def decorate(results)      
      results.each do |result|
        configuration.item_decorators.each do |decorator|
          decorator = (decorator.kind_of? Module) ? decorator : BentoSearch::Util.constantize(decorator)          
          result.extend decorator
        end
      end
    end
    
    # What exceptions should our #search wrapper rescue and turn
    # into failed results instead of fatal errors? 
    #
    # Can't rescue everything, or we eat VCR/webmock errors, and lots
    # of other errors we don't want to eat either, making
    # development really confusing.  Perhaps could set this
    # to be something diff in production and dev?
    #
    # This default list is probably useful already, but individual
    # engines can override if it's convenient for their own error
    # handling. 
    def auto_rescue_exceptions
      [TimeoutError, HTTPClient::TimeoutError, 
            HTTPClient::ConfigurationError, HTTPClient::BadResponseError,
            MultiJson::DecodeError, Nokogiri::SyntaxError]
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
