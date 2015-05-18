module BentoSearch
  # Represents an 'additional link' held in BentoSearch::ResultItem#other_links
  #
  # label, url, other metadata about the link. 
  class Link
    include BentoSearch::Results::Serialization

    serializable_attr_accessor :label
    # url is normally a string, but can also be a Hash passed
    # to url_for in the local app. 
    serializable_attr_accessor :url
    
    # Used both for HTML links and possibly later Atom. 
    # Must be a string, EITHER a complete URL (representing
    # vocab term), OR a legal short name from 
    # http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#linkTypes    
    serializable_attr_accessor :rel
    
    # MIME content type may be used for both HMTL links and Atom
    # link 'type' attribute
    serializable_attr_accessor :type
    
    # Array of strings, used for CSS classes on this link, possibly
    # for custom styles/images etc. May be used in non-html link
    # contexts too. 
    serializable_attr_accessor :style_classes
    
    # Suggested `target` attribute to render link with as html <a> 
    serializable_attr_accessor :target
    
    def initialize(hash = {})
      self.style_classes = []
      
      hash.each_pair do |key, value|
        send("#{key}=", value)
      end            
    end
    
  end
end
