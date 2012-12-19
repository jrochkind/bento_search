require 'delegate'

module BentoSearch
  class DecoratorBase < SimpleDelegator
    def initialize(base, view_context)
      super(base)
      
      @view_context = view_context
    end
    
    def _h
      @view_context
    end    
  end  
end
