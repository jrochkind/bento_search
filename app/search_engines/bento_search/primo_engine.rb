require 'cgi'
require 'nokogiri'

require 'http_client_patch/include_client'
require 'httpclient'

# ExLibris Primo Central. 
#
# written/tested with PrimoCentral aggregated index only, but probably
# should work with any Primo, may need some assumption tweaks.
#
# == Required Configuration
#
# [:host_port] your unique Primo's host/port combo, like "something.exlibrisgroup.com:1701".
#              it's assumed we can talk to your primo at 
#              http://$host_port/PrimoWebServices/xservice/search/brief?
# [:institution] Primo requires an institution paramter. 
#                right now we have a hard-coded assumed 'institution' in
#                config. Eg. "GWCC"
#   
#
# == Other Primo-Specific Configuration
#
# [:loc]  The primo 'loc' paramter, default "adaptor,primo_central_multiple_fe"
#         for Primo Central Index searches.
# [:auth] Set to 'true' to assume local auth'd users if you're going to protect
#         access. Default false. Alternately, you can pass in an 
#         :auth => true/false to 'search', which will override config. 
#         PC has limited access for non-auth users. 
# [:lang] Primo lang query param. "Hints input languages to search engine for language recognition. "
#         For now hardcoded into config, not settable per request.default 'eng' 
#
# == Vendor docs
#
# http://www.exlibrisgroup.org/display/PrimoOI/Brief+Search

class BentoSearch::PrimoEngine
  include BentoSearch::SearchEngine
  
  extend HTTPClientPatch::IncludeClient
  include_http_client
  
  def search_implementation(args)
    url = construct_query(args)
    
    response = http_client.get(url)
    response_xml = Nokogiri::XML response.body
    # namespaces really do nobody any good
    response_xml.remove_namespaces!
    
    results = BentoSearch::Results.new
    
    results.total_items = response_xml.at_xpath("./SEGMENTS/JAGROOT/RESULT/DOCSET")["TOTALHITS"].to_i

    response_xml.xpath("./SEGMENTS/JAGROOT/RESULT/DOCSET/DOC").each do |doc_xml|
      item = BentoSearch::ResultItem.new
      # Data in primo response is confusing in many different places in
      # variant formats. We try to pick out the best to take things from,
      # but we're guessing, it's under-documented.
      
      item.title      = text_at_xpath(doc_xml, "./PrimoNMBib/record/display/title")
      item.abstract   = text_at_xpath(doc_xml, "./PrimoNMBib/record/addata/abstract") 
      

      doc_xml.xpath("./PrimoNMBib/record/facets/creatorcontrib").each do |author_node|
        item.authors << BentoSearch::Author.new(:display => author_node.text)
      end

            
      item.journal_title  = text_at_xpath(doc_xml, "./PrimoNMBib/record/addata/jtitle")
      # check btitle for book chapters, the book they are in. 
      if item.journal_title.blank? && doc_xml.at_xpath("./PrimoNMBib/record/display/ispartof")
        item.journal_title = text_at_xpath(doc_xml, "./PrimoNMBib/record/addata/btitle")
      end
      
      item.publisher      = text_at_xpath doc_xml, "./PrimoNMBib/record/display/publisher"
      item.volume         = text_at_xpath doc_xml, "./PrimoNMBib/record/addata/volume"
      item.issue          = text_at_xpath doc_xml, "./PrimoNMBib/record/addata/issue"
      item.start_page     = text_at_xpath doc_xml, "./PrimoNMBib/record/addata/spage"
      item.end_page       = text_at_xpath doc_xml, "./PrimoNMBib/record/addata/epage"
      item.doi            = text_at_xpath doc_xml, "./PrimoNMBib/record/addata/doi"
      item.issn           = text_at_xpath doc_xml, "./PrimoNMBib/record/addata/issn"
      item.isbn           = text_at_xpath doc_xml, "./PrimoNMBib/record/addata/isbn"
      
      if (date = text_at_xpath doc_xml, "./PrimoNMBib/record/search/creationdate")
        item.year = date[0,4] # first four chars
      end
      
      if fmt_str = text_at_xpath(doc_xml, "./PrimoNMBib/record/search/rsrctype")
        # 'article', 'book_chapter'. abuse rails to turn into nice titlelized english. 
        item.format_str     = fmt_str.titleize
        
        item.format         = map_format fmt_str
      end
      
      
      
      #TODO formats, highlighting
      
      results << item
    end
    
    
    return results
  end
  
  # Try to map from primocentral's 'rsrctype' to our own internal
  # taxonomy of formats
  #
  # Need docs on what the complete Primo vocabulary here is, we're
  # just guessing from what we see. 
  def map_format(str)    
    case str
    when "article", "newspaper_article", "review"        
      then "Article"
    when "book"           then "Book"
    when "dissertation"   then :dissertation
    end    
  end
  
  # Returns the text() at the xpath, if the xpath is non-nil
  # and the text is non-blank
  def text_at_xpath(xml, xpath)
    node = xml.at_xpath(xpath)    
    return nil if node.nil?    
    text = node.text    
    return nil if node.blank?    
    return text
  end
    
  
  
  # From config or args, args over-ride config
  def authenticated_end_user?(args)    
    config = configuration.auth ? true : false
    arg = args[:auth]
    if ! arg.nil?
      arg ? true : false
    elsif ! config.nil?
      config ? true : false
    else
      false
    end
  end
  
  # Docs say we need to replace any commas with spaces
  def prepared_query(str)
    str.gsub(/\,/, ' ')
  end
    
    
  def construct_query(args)
    url = "http://#{configuration.host_port}/PrimoWebServices/xservice/search/brief"
    url += "?institution=#{configuration.institution}"
    url += "&loc=#{CGI.escape configuration.loc}"
    
    url += "&lang=#{CGI.escape configuration.lang}"
    
    url += "&bulkSize=#{args[:per_page]}" if args[:per_page]
    # primo indx is 1-based record index, our :start is 0-based.
    url += "&indx=#{args[:start] + 1}" if args[:start]
    

    
    if (defn = self.sort_definitions[ args[:sort] ]) &&
        (value = defn[:implementation])
      
      url += "&sortField=#{CGI.escape value}"      
    end
    
  
    url += "&onCampus=#{ authenticated_end_user?(args) ? 'true' : 'false'}"
    
    
    query = "any,contains,#{prepared_query args[:query]}"
    
    url += "&query=#{CGI.escape query}"
    
    return url
  end
  
  
  def search_field_definitions
    # others are avail too, this is not exhaustive. 
    {
      "creator"   => {:semantic => :author},
      "title"     => {:semantic => :title}
      "sub"       => {:semantic => :subject}      
      "isbn"      => {:semantic => :isbn}
      "issn"      => {:semantic => :issn}
    }
  end
  
  def sort_definitions
    { 
      "title_asc"       => {:implementation => "stitle"},
      "date_desc"       => {:implementation => "scdate"},
      "author_asc"      => {:implementation => "screator"},
      # As far as I can tell, what they call 'popularity'
      # is really relevance, with popularity boosting. 
      "relevance"       => {:implementation => "popularity"}
    }
  end
  
  def self.required_configuration
    [:host_port, :institution]
  end
  
  def self.default_configuration
    {
      :loc => 'adaptor,primo_central_multiple_fe',
      # "eng" or "fre" or "ger" (Code for the representation of name of language conform to ISO-639) 
      :lang => "eng"
    }
  end
  
end
