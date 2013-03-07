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
  #   (Except you can't call html_escape that way becuase Rails makes it
  #   private for some reason, wtf. We provide an html_escape) 
  # 
  # Inside a decorator, access #_base to get undecorated base model. 
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
      @base = base
    end
    
    def _h
      @view_context
    end    
    
    def _base
      @base
    end
    
    # _h.html_escape won't work because Rails makes html_escape
    # private for some weird reason. We provide our own here instead. 
    def html_escape(*args, &block)
      ERB::Util.html_escape(*args, &block)
    end
    
    # Applies decorator to item and returns decorated item. 
    # Will decide what decorator to apply based on String class name
    # in item.decorator, or else apply StandardDecorator. The point of 
    # this method is just that logic, nothing else special. 
    #
    # Need to pass a Rails ActionView::Context in, to use to
    # initialize decorator. In Rails, in most places you can
    # get one of those from #view_context. In helpers/views 
    # you can also use `self`. 
    def self.decorate(item, view_context)
      # What decorator class? Specified in #decorator as a String,
      # we intentionally do not allow an actual class constant, to
      # maintain problem-free serialization of ItemResults and configuration. 
      decorator_class = item.decorator.try do |arg|
        BentoSearch::Util.constantize(arg.to_s)           
      end || BentoSearch::StandardDecorator
      
      return decorator_class.new(item, view_context)    
    end
    
  end  
end
