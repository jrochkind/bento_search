module BentoSearch
  #
  # Export a BentoSearch::ResultItem in RIS format, as a file
  # to import into EndNote etc, or in a callback for Refworks export, etc. 
  #
  # RISCreator.new( result_item ).export
  #
  # Note: We assume input and output in UTF8. The RIS spec kind of says
  # it has to be ascii only, but most actual software seems to be able to do
  # UTF8. 
  #
  # Note: If you want your decorator to be taken into account in links
  # or other data, you have to make sure it's applied. If you got result_item
  # from SearchEngine#get, you should apply decorators yourself:
  #
  #    RISCreator.new(  BentoSearch::StandardDecorator.decorate(result_item) ).export
  # 
  #
  # Best spec/docs for RIS format seems to be at 
  # http://www.refman.com/support/risformat_intro.asp
  # Download zip file there, pay attention to excel spreadsheet
  # as well as PDF overview. 
  #
  # But note this 'spec' is often ignored/violated, even by the vendors
  # who wrote it. Wikipedia at http://en.wikipedia.org/wiki/RIS_(file_format)#Tags
  # contains some additional tags not mentioned in 'spec'. 
  class RISCreator
    def initialize(i)
      @item = i
      @ris_format = translate_ris_format
    end
    
    def export
      out = "".force_encoding("UTF-8")
      
      out << tag_format("TY", @ris_format)
      
      out << tag_format("TI", @item.title)
      
      @item.authors.each do |author|
        out << tag_format("AU", format_author_name(author))
      end
      
      out << tag_format("PY", @item.year)
      out << tag_format("DA", format_date(@item.publication_date))
      
      out << tag_format("LA", @item.language_str)
      
      out << tag_format("VL", @item.volume)
      out << tag_format("IS", @item.issue)
      out << tag_format("SP", @item.start_page)
      out << tag_format("EP", @item.end_page)
      
      out << tag_format("T2", @item.source_title)
      
      # ISSN and ISBN both share SN, sigh. 
      out << tag_format("SN", @item.issn)
      out << tag_format("SN", @item.isbn)
      out << tag_format("DO", @item.doi)
      
      out << tag_format("PB", @item.publisher)
      
      out << tag_format("AB", @item.abstract)
      
      # include main link and any other links?
      out << tag_format("UR", @item.link)
      @item.other_links.each do |link|
        out << tag_format("UR", link.url)
      end
      
      # end with blank lines, so multiple ones can be concatenated for
      # a file. 
      out << "\r\nER  - \r\n\r\n"
    end
    
    @@format_map = {
      # bento_search doesn't distinguish between journal, magazine, and newspaper,
      # RIS does, sorry, we map all to journal article. 
      "Article"         => "JOUR",
      "Book"            => "BOOK",
      "Movie"           => "MPCT",
      "MusicRecording"  => "MUSIC",
      #"Photograph"     => "GEN",
      "SoftwareApplication" => "COMP",
      "WebPage"         => "ELEC",
      "VideoObject"     => "VIDEO",
      "AudioObject"     => "SOUND",
      :serial           => "SER",
      :dissertation     => "THES",
      :conference_paper => "CPAPER",
      :conference_proceedings => "CONF",
      :report           => "RPRT",
      :book_item        => "CHAP"      
    }
    
    # based on current @item.format, output
    # appropriate RIS format string
    def translate_ris_format
      # default "GEN"=generic if unknown 
      @@format_map[@item.format] || "GEN"
    end
    
    # Formats refworks tag/value line and returns it. 
    # 
    # Returns empty string if you pass in an empty value though. 
    # 
    # "Each six-character tag must be in the following format:
    # "<upper-case letter><upper-case letter or number><space><space><dash><space>"
    #
    # "Each tag and its contents must be on a separate line, 
    # preceded by a "carriage return/line feed" (ANSI 13 10)."
    #
    # "Note, however, that the asterisk (character 42)
    # is not allowed in the author, keywords or periodical name fields."
    #
    # The spec also seems to say ascii-only, but I don't think that's true
    # for actually existing software, we do utf-8. 
    #
    # Refworks MAY require unicode composed normalization if it accepts utf8
    # at all. but not doing that yet. http://bibwild.wordpress.com/2010/04/28/refworks-problems-importing-diacritics/
    def tag_format(tag, value)
      return "" if value.blank?
      
      raise ArgumentError.new("Illegal RIS tag") unless tag =~ /[A-Z][A-Z0-9]/
      
      # "T2" seems to be the only "journal name field", which is
      # mentioned along with these others as not being allowed to contain
      # asterisk. 
      if ["AU", "A2", "A3", "A4", "KW", "T2"].include? tag
        value = value.gsub("*", " ")
      end
      
      return "\r\n#{tag}  - #{value}"
    end    
    
    # Take a ruby Date and translate to RIS date format
    # "YYYY/MM/DD/other info"
    # 
    # returns nil if input is nil. 
    def format_date(d)
      return nil if d.nil?
      
      return d.strftime("%Y/%m/%d")
    end
    
    # RIS wants `Last, First M.`, we'll do what we can. 
    def format_author_name(author)
      if author.last.present? && author.first.present?
        str = "#{author.last}, #{author.first}"
        if author.middle.present?
          middle = author.middle
          middle += "." if middle.length == 1
          str += " #{middle}"
        end
        return str
      elsif author.display.present?
        return author.display
      elsif author.last.present?
        return author.last?
      else
        return nil
      end        
    end
    
  end
end
