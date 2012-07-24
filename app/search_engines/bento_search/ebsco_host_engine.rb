require 'nokogiri'

require 'http_client_patch/include_client'
require 'httpclient'

# Right now for EbscoHost API (Ebsco Integration Toolkit/EIT), 
# may be expanded or refactored for EDS too.
#
# == Required Configuration
#
# * profile_id
# * profile_password
# * databases: ARRAY of ebsco shortcodes of what databases to include in search. If you specify one you don't have access to, you get an error message from ebsco, alas. 
#
# == Note on configuration on EBSCO end
#
# If you log in to the 
#
#
# == Vendor documentation 
#
# Vendor documentation is a bit scattered, main page:
# * http://support.ebsco.com/eit/ws.php
# Some other useful pages we discovered:
# * http://support.ebsco.com/eit/ws_faq.php
# * search syntax examples: http://support.ebsco.com/eit/ws_howto_queries.php
# * Try construct a query: http://eit.ebscohost.com/Pages/MethodDescription.aspx?service=/Services/SearchService.asmx&method=Search
# * The 'info' service can be used to see what databases you have access to. 
# * DTD of XML Response, hard to interpret but all we've got: http://support.ebsco.com/eit/docs/DTD_EIT_WS_searchResponse.zip
#
#
# 
#
# TODO: David Walker tells us we need to configure in EBSCO to make default operator be 'and' instead of phrase search!
# We Do need to do that to get reasonable results. 
class BentoSearch::EbscoHostEngine
  include BentoSearch::SearchEngine
  
  extend HTTPClientPatch::IncludeClient
  include_http_client
  
  def search_implementation(args)
    url = query_url(args)
    
    results = BentoSearch::Results.new
    xml, response, exception = nil, nil, nil
    
    begin
      response = http_client.get(url)
      xml = Nokogiri::XML(response.body)
    rescue TimeoutError, HTTPClient::ConfigurationError, HTTPClient::BadResponseError, Nokogiri::SyntaxError  => e
        exception = e        
    end
    
    # the namespaces they provide are weird and don't help and sometimes
    # not clearly even legal. Remove em!
    xml.remove_namespaces!
    
    results.total_items = xml.at_xpath("./searchResponse/Hits").text.to_i
    
    xml.xpath("./searchResponse/SearchResults/records/rec").each do |xml_rec|
      results << item_from_xml( xml_rec )
    end
    
    return results
    
  end
  
  # Pass in a nokogiri node, return node.text, or nil if
  # arg was nil or node.text was blank?
  def text_if_present(node)
    if node.nil? || node.text.blank?
      nil
    else
      node.text
    end    
  end
  
  # it's unclear if ebsco API actually allows escaping of special chars,
  # or what the special chars are. But we know parens are special, can't
  # escape em, we'll just remove em (should not effect search). 
  def ebsco_query_escape(txt)
    txt.gsub(/[)(]/, ' ')
  end
  
  def query_url(args)
    
    url = 
      "#{configuration.base_url}/Search?prof=#{configuration.profile_id}&pwd=#{configuration.profile_password}"
    
    url += "&query=#{CGI.escape(ebsco_query_escape  args[:query]  )}"
    
    # startrec is 1-based for ebsco, not 0-based like for us. 
    url += "&startrec=#{args[:start] + 1}" if args[:start]
    url += "&numrec=#{args[:per_page]}" if args[:per_page]
    
    # Make relevance our default sort, rather than EBSCO's date. 
    args[:sort] ||= "relevance"
    url += "&sort=#{ sort_definitions[args[:sort]][:implementation]}"
    
    # Contrary to docs, don't pass these comma-seperated, pass em in seperate
    # query params. 
    configuration.databases.each do |db|
      url += "&db=#{db}"
    end    
    
    return url
  end
  
  # pass in a nokogiri representing an EBSCO <rec> result,
  # we'll turn it into a BentoSearch::ResultItem. 
  def item_from_xml(xml_rec)
    info = xml_rec.at_xpath("./header/controlInfo")
    
    item = BentoSearch::ResultItem.new
    
    item.issn           = text_if_present info.at_xpath("./jinfo/issn") 
    item.journal_title  = text_if_present info.at_xpath("./jinfo/jtl")
    item.publisher      = text_if_present info.at_xpath("./pubinfo/pub")
    # Might have multiple ISBN's in record, just take first for now
    item.isbn           = text_if_present info.at_xpath("./bkinfo/isbn")
    
    item.volume         = text_if_present info.at_xpath("./pubinfo/vid")
    item.issue          = text_if_present info.at_xpath("./pubinfo/iid")
    #TODO year
    
    item.title          = text_if_present info.at_xpath("./artinfo/tig/atl")
    item.start_page     = text_if_present info.at_xpath("./artinfo/ppf")
    item.doi            = text_if_present info.at_xpath("./artinfo/ui[type=doi]")
    
    item.abstract       = text_if_present info.at_xpath("./artinfo/ab")
    # EBSCO abstracts have an annoying habit of beginning with "Abstract:"
    if item.abstract
      item.abstract.gsub!(/^Abstract\: /, "")
    end
    
    # authors, only get full display name from EBSCO. 
    info.xpath("./artinfo/aug/au").each do |author|
      a = BentoSearch::Author.new(:display => author.text)
      item.authors << a
    end
    
    return item
  end
  
  # David Walker says pretty much only relevance and date are realiable
  # in EBSCOhost cross-search. 
  def sort_definitions
    { 
      "relevance" => {:implementation => "relevance"},
      "date_desc" => {:implementation => "date"}
    }      
  end
  
  def max_per_page
    # Actually only '50' if you ask for 'full' records, but I don't think
    # we need to do that ever, that's actually getting fulltext back! 
    200
  end
  
  def self.required_configuration
    ["profile_id", "profile_password"]
  end
  
  def self.default_configuration
    {
      # /Search
      :base_url => "http://eit.ebscohost.com/Services/SearchService.asmx"    
    }
  end
  
end
