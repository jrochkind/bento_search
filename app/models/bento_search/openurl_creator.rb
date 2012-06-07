require 'openurl'

module BentoSearch
  
  # Helper class used to take a ResultItem, and construct
  # a ruby OpenURL::ContextObject out of it. That represents
  # a NISO Z39.88 OpenURL context object, useful for using
  # with linking software that expects such. http://en.wikipedia.org/wiki/OpenURL
  #
  #     co = OpenurlCreator.new(  result_item ).to_open_url
  #        # => ruby OpenURL::ContextObject object.
  #
  #     co.kev 
  #        # => context object serialized to KEV format (URL query string) 
  #
  # In some cases nil can be returned, if no reasonable OpenURL can
  # be created from the ResultItem. 
  class OpenurlCreator
    attr_accessor :result_item
    
    def initialize(ri)
      self.result_item = ri
    end
    
    def to_openurl
      # If we have a pre-constructed KEV, just use it. 
      if result_item.openurl_kev_co
        return OpenURL::ContextObject.new_from_kev( result_item.openurl_kev_co )
      end
      
      
      context_object = OpenURL::ContextObject.new
      
      r = context_object.referent
      
      r.set_format( self.format )
      
      if result_item.doi
        r.add_identifier("info:doi:#{result_item.doi}")
      end
      
      r.set_metadata("genre", self.genre)
      
      if result_item.authors.length > 0
        r.set_metadata("aufirst", result_item.authors.first.first)
        r.set_metadata("aulast", result_item.authors.first.last)
        r.set_metadata("au", result_item.author_display(result_item.authors.first))
      end

      r.set_metadata("date",    result_item.year)
      r.set_metadata("volume",  result_item.volume)
      r.set_metadata("issue",   result_item.issue)
      r.set_metadata("spage",   result_item.start_page)
      r.set_metadata("epage",   result_item.end_page)
      r.set_metadata("jtitle",  result_item.journal_title)
      r.set_metadata("issn",    result_item.issn)
      r.set_metadata("isbn",    result_item.isbn)
      r.set_metadata("pub",     result_item.publisher)
      
      case result_item.format
      when "Book"
        r.set_metadata("btitle", result_item.complete_title)
      when "Article"
        r.set_metadata("atitle", result_item.complete_title)
      else
        r.set_metadata("title", result_item.complete_title)
      end
      
      return context_object
    end      
      
    
    # rft.genre value. Yeah, the legal ones differ depending on openurl
    # 'format', but we've given up trying to do things strictly legal, 
    # OpenURL is a bear, we do things as generally used and good enough.
    # 
    # can be nil. 
    def genre
      case result_item.format
        when "Book"
          "book"
        when :book_item
          "bookitem"
        when :conference_paper
          "proceeding"
        when :conference_proceedings
          "conference"
        when :report
          "report"
        when :serial
          "journal"
        when "Article"
          "article"
        else
          nil
      end          
    end
    
    
    # We need to map from our formats to which OpenURL 'format'
    # we're going to create. 
    #
    # We only pick from a limited set of standard scholarly citation formats,
    # that's all any actual widespread software recognizes.
    #
    # Returns the last component of a valid format from:
    # http://alcme.oclc.org/openurl/servlet/OAIHandler?verb=ListRecords&metadataPrefix=oai_dc&set=Core:Metadata+Formats
    #
    # Eg, "book", "journal", "dissertation". 
    #
    # In fact, we only pick from one of those three -- by default, if we
    # can't figure out exactly what it is or can't map it to a specific
    # format, we'll return 'journal', never nil. 'journal' serves, in practice, 
    # with much actual software, as a neutral default. 
    def format
      case result_item.format
      when "Book"
        "book"
      when :dissertation
        "dissertation"
      else
        "journal"
      end
    end
    
    
  end
end
