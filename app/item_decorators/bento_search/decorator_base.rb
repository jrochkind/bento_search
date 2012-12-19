require 'delegate'

module BentoSearch
  # A delegator with an ActionView context. 
  # You can access the ActionView context at _h , to call Rails helper
  # methods (framework or app specific, whatever should be avail at
  # given context)
  #
  # inside a method in a decorator, `_h.content_tag` or `_h.html_escape`
  # or `_h.url_for` etc.   
  #
  # Except you can't call html_escape that way becuase Rails makes it
  # private for some reason, wtf. We provide an html_escape 
  class DecoratorBase < SimpleDelegator
    
    def initialize(base, view_context)
      super(base)
      
      
      # This worked to make html_escape avail at _h.html_escape, but
      # yfeldblum warned it messes up the method lookup cache, so
      # we just provide a straight #html_escape instead.  
      #if view_context.respond_to?(:html_escape, true)
        # thanks yfeldblum in #rails for this simple way to make
        # html_escape public, which I don't entirely understand myself. :)
       
      #  class << view_context
      #    public :html_escape
      #  end        
      #end      
      
      @view_context = view_context
    end
    
    def _h
      @view_context
    end    
    
    # _h.html_escape won't work because Rails makes html_escape
    # private for some weird reason. We provide our own here instead. 
    def html_escape(*args, &block)
      ERB::Util.html_escape(*args, &block)
    end
    
  end  
end
