require 'language_list'

module BentoSearch
  # Data object representing a single hit from a search, normalized
  # with common data fields. Usually held in a BentoSearch::Results object.
  #
  # ANY field can be nil, clients should be aware.  
  #
  # Each item has a field for one main link as string url, at #link (which may be nil),
  # as well as array of possibly additional links (with labels and metadata)
  # under #other_links.  #other_links is an array of BentoSearch::Link 
  # objects. 
  class ResultItem
    include ERB::Util # for html_escape for our presentational stuff
    include ActionView::Helpers::OutputSafetyHelper # for safe_join
    
    # Can initialize with a hash of key/values
    def initialize(args = {})
      args.each_pair do |key, value|
        send("#{key}=", value)
      end
      
      self.authors ||= []
      self.other_links ||= []
      
      self.custom_data ||= {}
    end
    
    # If set to true, item will refuse to generate an openurl,
    # returning nil from #to_openurl or #openurl_kev
    attr_accessor :openurl_disabled 
    
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
    
    # normalized controlled vocab title, important this is supplied
    # if possible for OpenURL generation and other features. 
    #
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
    
    # uncontrolled presumably english-language format string.
    # if supplied will be used in display in place of controlled
    # format. 
    attr_accessor :format_str
    
    # Language of materials. Producer can set language_code to an ISO 639-1 (two
    # letter) or 639-3 (three letter) language code. If you do this, you don't
    # need to set language_str, it'll be automatically looked up. (Providing
    # language name in English at present, i18n later maybe). 
    #
    # Or, if you don't know the language code (or there isn't one?), you can set 
    # language_str manually to a presumably english user-displayable string.
    # Manually set language_str will over-ride display string calculated from
    # language_code. 
    # 
    # Consumers can look at language_code or language_str regardless (although
    # either or both may be nil). You can use language_list gem to normalize to a 
    # 2- or 3-letter from language_code that could be either. 
    attr_accessor :language_code
    attr_writer :language_str
    def language_str
      @language_str || language_code.try do |code|
        LanguageList::LanguageInfo.find(code).name
      end
    end
    
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
    
    # source_title is often used for journal_title (and aliased
    # as #journal_title, although that may go away), but can
    # also be used for other 'container' titles. Book title for
    # a book chapter. Even web site or URL for a web page. 
    attr_accessor :source_title
    alias_method :journal_title, :source_title
    alias_method :'journal_title=',  :'source_title='
    
    
    attr_accessor :issn
    attr_accessor :isbn
    attr_accessor :oclcnum # OCLC accession number, WorldCat. 
    
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
    
    # engine-specific data not suitable for abstract API, usually
    # for internal use. 
    attr_accessor :custom_data
    
    
    # Returns a ruby OpenURL::ContextObject (NISO Z39.88).     
    def to_openurl
      return nil if openurl_disabled
      
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
        t = safe_join([t, ": ", self.subtitle], "")        
      end
      
      if t.blank?
        t = I18n.translate("bento_search.missing_title")
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
      
      result_elements.push(source_title) unless source_title.blank?      
      
      if source_title.blank? && ! publisher.blank?
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
