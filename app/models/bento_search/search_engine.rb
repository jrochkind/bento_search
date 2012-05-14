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
  module SearchEngine
    extend ActiveSupport::Concern
    
    included do
      attr_accessor :configuration
    end
    
    # If specific SearchEngine calls initialize, you want to call super
    # handles configuration loading, mostly. Argument is a
    # Confstruct::Configuration. 
    def initialize(aConfiguration)
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
    
  end
end
