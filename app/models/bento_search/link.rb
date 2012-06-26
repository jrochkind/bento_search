module BentoSearch
  # Represents an 'additional link' held in BentoSearch::ResultItem#other_links
  #
  # label, url, other metadata about the link. 
  class Link
    # url is normally a string, but can also be a Hash passed
    # to url_for in the local app. 
    attr_accessor :label, :url
    
    # Used both for HTML links and possibly later Atom. 
    # Must be a string, EITHER a complete URL (representing
    # vocab term), OR a legal short name from 
    # http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#linkTypes    
    attr_accessor :rel
    
    # Array of strings, used for CSS classes on this link, possibly
    # for custom styles/images etc. May be used in non-html link
    # contexts too. 
    attr_accessor :style_classes
    
    def initialize(hash = {})
      self.style_classes = []
      
      hash.each_pair do |key, value|
        send("#{key}=", value)
      end            
    end
    
  end
end
