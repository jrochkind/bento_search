require 'nokogiri'

require 'http_client_patch/include_client'
require 'httpclient'

# Attempt to search using the WorldCat Search SRU variant, asking API for
# results in DC format. We'll see how far this takes us. 
#
# Does require an API key, and requires OCLC membership/FirstSearch subscription
# for access. 
#
# link is set to worldcat.org link. Change config link_base_url to, say,
# link to a worldcat local instance. 
#
# == Limitations
# Worldcat SRU APU provides _very little_ usable data on format/type. We provide
# some limited heuristics to try and clean up what IS there, but user-displayable
# format_str may be weird sometimes (and is frequently 'Text'), and machine
# readable semantic #format is often defaulted to "Book", which may not
# always be right. 
#
# WorldCat doesn't let you paginate past start_record 9999. If client asks,
# this engine will silenly reset to 9999. 
#
# == API Docs
# * http://oclc.org/developer/documentation/worldcat-search-api/using-api
# * http://oclc.org/developer/documentation/worldcat-search-api/sru
# * http://oclc.org/developer/documentation/worldcat-search-api/parameters
# * http://oclc.org/developer/documentation/worldcat-search-api/service-levels
# * http://oclc.org/developer/documentation/worldcat-search-api/complete-list-indexes
#
# == Required configuration keys
# * api_key
#
# == Optional configuration keys
# [frbrGrouping]   default nil, use worldcat default (which is 'on'). 
#                  See http://oclc.org/developer/documentation/worldcat-search-api/parameters
#                  for meaning of frbrGrouping. set to true or false. 
# [auth]           default false. Set to true to assume all users are authenticated
#                  and servicelevel=full for OCLC. 
#
# == Extra search args
#
# [auth]           default false. Set to true to specify current user is authenticated
#                  and servicelevel=full for OCLC. Overrides config 'auth' value.  
#
class BentoSearch::WorldcatSruDcEngine
  include BentoSearch::SearchEngine
  
  extend HTTPClientPatch::IncludeClient
  include_http_client
  
  MaxStartRecord = 9999 # at least as of Sep 2012, worldcat errors if you ask for pagination beyond this
  
  def search_implementation(args)
    url = construct_query_url(args)

    results = BentoSearch::Results.new

    response = http_client.get(url)
    
    # check for http errors
    if response.status != 200
      results.error ||= {}
      results.error[:status] = response.status
      results.error[:info] = response.body
      results.error[:url] = url
      
      return results    
    end
    
    xml = Nokogiri::XML(response.body)
    # namespaces only get in the way
    xml.remove_namespaces!
    
    
    results.total_items = xml.at_xpath("//numberOfRecords").try {|n| n.text.to_i }
    
    
    # check for SRU fatal errors, no results AND a diagnostic message
    # is a fatal error always, I think. 
    if (results.total_items == 0 && 
        error_xml = xml.at_xpath("./searchRetrieveResponse/diagnostics/diagnostic"))
    
      results.error ||= {}
      results.error[:info] = error_xml.children.to_xml
    end    
    
    (xml.xpath("/searchRetrieveResponse/records/record/recordData/oclcdcs") || []).each do |record|
      item = BentoSearch::ResultItem.new
      
      item.title        = first_text_if_present record, "title"
      
      # May have one (or more?) 'creator' and one or more 'contributor'. 
      # We'll use just creators if we got em, else contributors. 
      authors = record.xpath("./creator")
      authors = record.xpath("./contributor") if authors.empty?
      authors.each do |auth_node|
        item.authors << BentoSearch::Author.new(:display => auth_node.text)
      end
      
      
      # date may have garbage in it, just take the first four digits
      item.year         = record.at_xpath("date").try do |date_node|
        date_node.text =~ /(\d{4})/ ? $1 : nil          
      end
      
      # weird garbled from MARC format, best we have
      (item.format, item.format_str) = format_heuristics(record)
      
      
      item.publisher    = first_text_if_present record, "publisher"
      
      # OCLC DC format gives us a bunch of jumbled 'description' elements
      # with any Marc 5xx. Sigh. We'll just concat em all and call it an
      # abstract, best we can do. 
      item.abstract     = record.xpath("description").collect {|n| n.text}.join("... \n")
      
      # dc.identifier is a terrible smorgasbord of different identifiers,
      # with no way to tell for sure what's what other than pattern matching
      # of literals. sigh. 
      if ( id = first_text_if_present(record, "identifier"))
        possible_isxn = id.scan(/\d|X/).join('')
        # we could test check digit validity, but we ain't
        if possible_isxn.length == 10 || possible_isxn.length == 13
          item.isbn = possible_isxn
        elsif possible_isxn.length == 8
          item.issn = possible_isxn
        end
      end
      
      # The recordIdentifier with no "xsi:type" attrib is an oclcnum. sigh. 
      # lccn may also be in there if we wanted to keep it. 
      item.oclcnum        = first_text_if_present(record, "./recordIdentifier[not(@type)]")
      # oclcnum is our engine-specific unique id too. 
      item.unique_id      = item.oclcnum
      
      item.link           = "#{configuration.linking_base_url}#{item.oclcnum}"
      
      item.language_code  = first_text_if_present record, "./language[@type='http://purl.org/dc/terms/ISO639-2']"
      
      results << item
    end
    
    return results
  end
  
  # get a single record, by it's #unique_id (which is also an oclcnum), 
  # returns record, or raises BentoSearch::NotFound, BentoSearch::TooManyFound,
  # or possibly something weird. 
  def get(id)
    results = search(id, :semantic_search_field => :oclcnum)

    raise (results.error[:exception] || Exception.new(results.error)) if results.failed?
    raise BentoSearch::NotFound.new("ID: #{id}") if results.total_items == 0
    raise BentoSearch::TooManyFound.new("ID: #{ID}") if results.total_items > 1
    
    return results.first    
  end
  
  # Note, if pagination start record is beyond what we think is worldcat's
  # max, it will silently reset to max, and mutate the args passed in
  # so pagination appears to be at max too!
  def construct_query_url(args)
    url = configuration.base_url
    url += "&wskey=#{CGI.escape configuration.api_key}"
    url += "&recordSchema=#{CGI.escape 'info:srw/schema/1/dc'}"
    
     
    url += "&maximumRecords=#{args[:per_page]}" if args[:per_page]
    
    # pagination, WorldCat 'start' is 1-based, ours is 0-based. Catch max.    
    if args[:start] && args[:start] > (MaxStartRecord-1)
      args[:start]  = MaxStartRecord - 1
      args[:page] = (args[:start] / (args[:per_page] || 10)) + 1
    end
    url += "&startRecord=#{args[:start] + 1}" if args[:start]
    
    url += "&query=#{CGI.escape construct_cql_query(args)}"
    
    if (args[:sort]) && (value = sort_definitions[args[:sort]].try {|h| h[:implementation]})
      url += "&sortKeys=#{CGI.escape value}"
    end    
    
    unless configuration.frbrGrouping.nil?
      value = configuration.frbrGrouping ? "on" : "off"
      url += "&frbrGrouping=#{value}"
    end
    
    # service level? search arg over-rides config
    auth = args[:auth]
    auth = configuration.auth if auth.nil?
    if auth
      url += "&servicelevel=full"
    end
    
    return url
  end
  
  # input is a nokogiri node for a recordData/oclcdcs representing a hit. (with
  # namespaces stripped). 
  # 
  # output is [format, format_str], based on rough guess heuristics of what
  # we can do, OCLC does not provide particularly useful data here for either
  # user display passthrough OR semantics, this is inherently flawed but better
  # than nothing. 
  def format_heuristics(record_xml)
    # default semantic format to "Book", it'll sometimes be wrong,
    # but right more often than it's wrong when we lack sufficient
    # info to know otherwise. 
    format = "Book"
    # user display string, default to none, unless we come up with something. 
    format_str = nil         
    
    if xpath_contains(record_xml, "./subject", "--Periodicals")
      # if a subject includes "--Periodicals", we're going to guess it's
      # a serial/journal.
      format = :serial
      format_str = "Journal or Serial"
    elsif record_xml.xpath("./type[text()='Image']").length > 0
      # "Image" can mean video OR actual images, only thing we
      # can do really for user-presentable format is use the terrible "./format",
      # which will often tell the user more (along with a bunch of weird stuff). 
      format_str = first_text_if_present(record_xml, "./format")
    elsif record_xml.xpath("./type[text()='Sound']").length > 0
      # No great thing to display to user to say what this really is,
      # but at least we know it's Sound. 
      format_str = first_text_if_present(record_xml, "./format") || "Sound"
      format = "AudioObject"
    elsif  record_xml.xpath("./description").find {|node| node.text =~ /^Thesis \([^)]+\)--/}
      # yeah, to tag it as a dissertation we've got to heursitically regex
      # a description value for looking like a thesis label. 
      format = :dissertation
      format_str = "Dissertation/Thesis"      
    elsif (type = first_text_if_present(record_xml, "./type"))
      # defaults, 
      # If we have a type, titleize it to change things like MovingImage to
      # 'Moving Image'. 
      format_str = type.titleize
    else 
      # if we don't even have a 'type', use the 'format' if it's there, 
      # even though it's gonna be weird. 
      format_str = first_text_if_present(record_xml, "format")      
    end        
    
    return [format, format_str]
    
  end
  
  def first_text_if_present(node, xpath)
    node.at_xpath(xpath).try {|n| n.text}
  end
  
  # if `node` has an `xpath` whose text() contains `text`.  
  # uses some tricky xpath, may not work with unsuual xpath passed in
  def xpath_contains(node, xpath, text)
    node.xpath(xpath).xpath("./text()[contains(.,'#{text}')]").length > 0
  end
    
  
  # construct valid CQL for the API's "query" param, from search
  # args. Tricky because we need to split terms/phrases ourselves
  #
  # returns CQL that is NOT uri escaped yet. 
  def construct_cql_query(args)
    if args[:query].kind_of?(Hash)
      # multi-field
      args[:query].collect {|field, query| fielded_cql_query(query, field)}.join(" AND ")
    else
      fielded_cql_query(args[:query], args[:search_field] || "srw.kw")
    end
  end

  # construct valid CQL for the API's "query" param, from search
  # args. Tricky because we need to split terms/phrases ourselves
  #
  # returns CQL that is NOT uri escaped yet. 
  def fielded_cql_query(query, field = nil)
    # default is srw.kw, Keyword anywhere. 
    field ||= "srw.kw" 
    
    # We need to split terms and phrases, so we can formulate
    # CQL with seperate clauses for each, bah. 
    tokens = query.split(%r{\s|("[^"]+")}).delete_if {|a| a.blank?}
    

    
    return tokens.collect do |token|
      quoted_token = nil
      if token =~ /^".*"$/
        # phrase
        quoted_token = token
      else
        # escape internal double quotes with single backslash. sorry ruby escaping
        # makes this crazy. 
        token = token.gsub('"', %Q{\\"})
        quoted_token = %Q{"#{token}"}
      end
      
      "#{field} = #{quoted_token}"
      end.join(" AND ")    
  end

  # date sort seems to work pretty terribly on worldcat. 
  # Author, Title, and "Score" (don't know what that is) also
  # avail on worldcat, asc and desc, but we aren't advertising here,
  # cause, who needs em. 
  def sort_definitions
    {
      "relevance" => {:implementation => "relevance"},
      "date_desc" => {:implementation => "Date,,0"},   
      "library_count_desc" => {:implementation => "Library Count,,0"}
    }
  end
  
  # WorldCat offers more search fields than this, this is what we
  # think is useful right now. Some WorldCat search fields are only
  # available at 'full' service level, but we think all the ones
  # we're listing now are available even at 'default' service level. 
  def search_field_definitions
    {
      nil           => {:semantic => :general},
      "srw.ti"      => {:semantic => :title},
      "srw.au"      => {:semantic => :author},
      "srw.su"      => {:semantic => :subject},
      "srw.bn"      => {:semantic => :isbn},
      "srw.in"      => {:semantic => :issn},
      "srw.dn"      => {:semantic => :lccn},
      # generic 'number', probably not useful
      "srw.sn"      => {:semantic => :number},
      "srw.no"      => {:semantic => :oclcnum}
    }
  end
  
  def max_per_page
    100
  end
  
  def self.required_configuration
    [:api_key]
  end
  
  def self.default_configuration
    {
      :base_url => "http://www.worldcat.org/webservices/catalog/search/sru?",
      :linking_base_url => "http://worldcat.org/oclc/",
      :auth => false
    }
  end

  def multi_field_search?
    true
  end
  
end
