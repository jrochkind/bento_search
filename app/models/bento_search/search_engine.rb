require 'active_support/concern'
require 'active_support/core_ext/module/delegation'
require 'confstruct'


module BentoSearch
  # Module mix-in for bento_search search engines. 
  #
  # ==Using a SearchEngine 
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
              
      return arguments
    end
    
    
  end
end
