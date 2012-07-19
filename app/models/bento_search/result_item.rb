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
      
      self.authors ||= []
      self.other_links ||= []
    end
    
    # Array (possibly empty) of BentoSearch::Link objects
    # representing additional links. Often SearchEngine's themselves
    # won't include any of these, but Decorators will be used
    # to add them in. 
    attr_accessor :other_links
    
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
    # is a valid schema.org type uri, that sub-types CreativeWork. Eg.
    # * Article
    # * Book
    # * Movie
    # * MusicRecording
    # * Photograph
    # * SoftwareApplication
    # * WebPage
    # * VideoObject
    # * AudioObject
    # * SoftwareApplication
    # 
    # 
    # 
    # OR one of these symbols, sadly not covered by schema.org types:
    # * :serial (magazine or journal)
    # * :dissertation (dissertation or thesis)
    # * :conference_paper  # individual paper
    # * :conference_proceedings # collected proceedings
    # * :report # white paper or other report.
    # * :book_item # section or exceprt from book.
    #
    # Note: We're re-thinking this, might allow uncontrolled
    # in here instead. 
    attr_accessor :format    
    
    # year published. a ruby int
    # PART of:. 
    # * schema.org CreativeWork "datePublished", year portion
    # * dcterms.issued, year portion
    # * prism:coverDate, year portion
    attr_accessor :year
    
    attr_accessor :volume
    attr_accessor :issue
    attr_accessor :start_page
    attr_accessor :end_page
    
    attr_accessor :journal_title
    attr_accessor :issn
    attr_accessor :isbn
    
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
    attr_accessor :authors
    
    
    # Returns a ruby OpenURL::ContextObject (NISO Z39.88).     
    def to_openurl
      BentoSearch::OpenurlCreator.new(self).to_openurl
    end
    
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
    
    # Put together title and subtitle if neccesary. 
    def complete_title
      t = self.title
      if self.subtitle
        t += ": #{self.subtitle}"
      end
      return t
    end
    
    
    
    # A simple user-displayable citation, _without_ author/title.
    # the journal, year, vol, iss, page; or publisher and year; etc. 
    # Constructed from individual details. Not formal APA or MLA or anything,
    # just a rough and ready display. 
    #
    # TODO: Should this be moved to a rails helper method? Not sure. 
    def published_in
      result_elements = []

      unless year.blank?
        # wrap year in a span so we can bold it. 
        result_elements.push "<span class='year'>#{year}</span>"
      end
      
      result_elements.push(journal_title) unless journal_title.blank?      
      
      if journal_title.blank? && ! publisher.blank?
        result_elements.push html_escape publisher
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
