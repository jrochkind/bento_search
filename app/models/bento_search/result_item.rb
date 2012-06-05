module BentoSearch
  # Data object representing a single hit from a search, normalized
  # with common data fields. Usually held in a BentoSearch::Results object.
  #
  # ANY field can be nil, clients should be aware.  
  class ResultItem
    include ERB::Util # for html_escape for our presentational stuff
    
    # Can initialize with a hash of key/values
    def initialize(args = {})
      args.each_pair do |key, value|
        send("#{key}=", value)
      end
      
      @authors = []
    end
    
    # * dc.title 
    # * schema.org CreativeWork: 'name'    
    attr_accessor :title
    
    # When an individual seperate subtitle is available. 
    # May also be nil with subtitle in "title" field after colon. 
    # 
    # * 
    attr_accessor :subtitle
    
    # usually a direct link to the search provider's 'native' page. 
    # Can be changed in actual presentation with a Decorator.
    # * schema.org CreativeWork: 'url'
    attr_accessor :link
    
    # schema.org 'type' that's a sub-type of CreativeWork. 
    # should hold a string that, when appended to "http://schema.org/"
    # is a valid schema.org type uri, that sub-types CreativeWork. 
    # 
    # OR one of these symbols, sadly not covered by schema.org types:
    # * :serial (magazine or journal)
    # * :dissertation (dissertation or thesis)
    attr_accessor :format
    
    # year published. a ruby int
    # PART of:. 
    # * schema.org CreativeWork "datePublished"
    # * dcterms.issued
    # * prism:?
    attr_accessor :year
    
    attr_accessor :volume
    attr_accessor :issue
    attr_accessor :start_page
    attr_accessor :end_page
    
    attr_accessor :journal_title
    attr_accessor :issn
    
    attr_accessor :doi
    
    # usually used for books rather than articles
    attr_accessor :publisher
    
    # an openurl kev-encoded context object. optional,
    # only if source provides one that may be better
    # than can be constructed from individual elements above
    attr_accessor :openurl_kev_co
    
    # Short summary of item. 
    # Mark .html_safe if it includes html -- creator is responsible
    # for making sure html is safely sanitizied and/or stripped,
    # rails ActionView::Helpers::Sanistize #sanitize and #strip_tags
    # may be helpful. 
    attr_accessor :abstract
    
    # An array (order matters) of BentoSearch::Author objects
    # add authors to it with results.authors << Author
    attr_reader :authors
    
    ##################
    # Presentation related methods. 
    # yes, it really makes sense to include them here, they can be overridden
    # by decorators. 
    # May extract these to their own base decorator module at some point,
    # but the OO hieararchy would be basically the same either way. 
    #######################
    
    
    # How to display a BentoSearch::Author object as a name
    def author_display(author)
      if (author.first && author.last)
        "#{author.last}, #{author.first.slice(0,1)}"
      elsif author.display
        author.display
      elsif author.last
        author.last
      else
        nil
      end
    end
    
    
    
    # A simple user-displayable citation, _without_ author/title.
    # the journal, year, vol, iss, page; or publisher and year; etc. 
    # Constructed from individual details. Not formal APA or MLA or anything,
    # just a rough and ready display. 
    #
    # TODO: Should this be moved to a rails helper method? Not sure. 
    def published_in
      result_elements = []
      
      result_elements.push(journal_title) unless journal_title.blank?
      
      if journal_title.blank? && ! publisher.blank?
        result_elements.push html_escape publisher
      end
      
      unless year.blank?
        # wrap year in a span so we can bold it. 
        result_elements.push "<span class='year'>#{year}</span>"
      end
      if (! volume.blank?) && (! issue.blank?)
        result_elements.push html_escape "#{volume}(#{issue})"
      else
        result_elements.push html_escape volume unless volume.blank?
        result_elements.push html_escape issue unless issue.blank?
      end
      
      if (! start_page.blank?) && (! end_page.blank?)
        result_elements.push html_escape "pp. #{start_page}-#{end_page}"
      elsif ! start_page.blank?
        result_elements.push html_escape "p. #{start_page}"
      end
      
      return nil if result_elements.empty?
      
      return result_elements.join(", ").html_safe
    end
    
  end
end
