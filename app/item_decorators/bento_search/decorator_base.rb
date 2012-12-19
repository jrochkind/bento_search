require 'delegate'

module BentoSearch
  # A delegator with an ActionView context. 
  # You can access the ActionView context at _h , to call Rails helper
  # methods (framework or app specific, whatever should be avail at
  # given context)
  #
  # inside a method in a decorator, `_h.content_tag` or `_h.html_escape`
  # or `_h.url_for` etc.   
  class DecoratorBase < SimpleDelegator
    def initialize(base, view_context)
      super(base)
      
      # for some reason html_escape is private in Rails, wtf. 
      # extend with our own weird custom thing to make it public
      # if html_escape exists privately.  
      if view_context.respond_to?(:html_escape, true)
        def view_context.html_escape(*args)
            super
        end
      end      
      
      @view_context = view_context
    end
    
    def _h
      @view_context
    end    
  end  
end
