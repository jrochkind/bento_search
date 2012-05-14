require 'active_support/concern'
require 'active_support/core_ext/module/delegation'
require 'confstruct'

module BentoSearch
  # Module mix-in for bento_search search engines. 
  # `include BentoSearch::SearchEngine`
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
    end
    
  end
end
