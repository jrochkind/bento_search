module BentoSearch
  class StandardDecorator < DecoratorBase
    
    ###################
    # turn into a representative OpenURL
    #
    #  use to_openurl_kev to go straight there, 
    #  or to_openurl to get a ruby OpenURL object.
    ###################
    

    # Returns a ruby OpenURL::ContextObject (NISO Z39.88).  
    # or nil if none avail. 
    def to_openurl
      return nil if openurl_disabled
      
      BentoSearch::OpenurlCreator.new(self).to_openurl
    end
    
    # Returns a kev encoded openurl, that is a URL query string representing
    # openurl. Or nil if none available. 
    #
    # Right now just calls #to_openurl.kev, can conceivably
    # be modified to do things more efficient, without a ruby openurl
    # obj. Law of demeter, represent.     
    def to_openurl_kev
      to_openurl.try(:kev)      
    end
    
  end
end
