# Right now for EbscoHost API (Ebsco Integration Toolkit/EIT), 
# may be expanded or refactored for EDS too.
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
# == Required Configuration
#
# * profile_id
# * profile_password
# * databases: ARRAY of ebsco shortcodes of what databases to include in search. If you specify one you don't have access to, you get an error message from ebsco, alas. 
#
# 
#
# TODO: David Walker tells us we need to configure in EBSCO to make default operator be 'and' instead of phrase search!
# We Do need to do that to get reasonable results. 
class BentoSearch::EbscoHostEngine
  include BentoSearch::SearchEngine
  

  
  def search_implementation(args)
    
  end
  
  def query_url(args)
    
    url = 
      "#{configuration.base_url}/Search?prof=#{configuration.profile_id}&pwd=#{configuration.profile_password}"
    
    url += "&query=#{CGI.escape(args[:query])}"
    
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
