require 'http_client_patch/include_client'
require 'httpclient'
require 'nokogiri'
require 'time'
require 'uri'

require 'summon'
require 'summon/transport/headers'

# Search engine for Serial Solutions Summon
#
# Docs: 
# http://api.summon.serialssolutions.com/help/api/search
# http://api.summon.serialssolutions.com/help/api/search/fields
# 
# Can try out searches and see XML results with an auth login in their
# interface: http://api.summon.serialssolutions.com/help/api/search/example?s.q=query
#
# An example user-facing Summon UI, useful for figuring out available
# facets and facet values, or trying out searches:
# http://ncsu.summon.serialssolutions.com/

#
# == Functionality notes
#
# * for pagination, underlying summon API only supports 'page', not 'start'
#   style, if you pass in 'start' style it will be 'rounded' to containing 'page'. 
#
# == Required config params
# [access_id]   supplied by SerSol for your account
# [secret_key]  supplied by SerSol for your account
#
# == Optional custom config params
#
# [fixed_params]  
#     Fixed SerSol query param literals to send with every search.
#     Value is a HASH, of keys and either single values or arrays
#     of values. For instance, to exclude certain content types
#     from all search results, in config:
#         :fixed_params => 
#           {"s.fvf" => ["ContentType,Web Resource,true","ContentType,Reference,true","ContentType,eBook,true"] }
#     Note that values are NOT URI escaped in config, code will take care
#     of that for you. You could also fix "s.role" to 'authenticated' using
#     this mechanism, if you restrict all access to your app to authenticated
#     affiliated users. 
# [highlighting]
#     Default true, ask SerSol for query-in-context highlighting in
#     title and snippets field. If true you WILL get HTML with <b> tags
#     in your titles.  
# [snippets_as_abstract]
#     Defaults true, if true and :highlighting is true, we'll put the
#     query-in-context snippets in the 'abstract' field. Set :max_snippets
#     for how many to possibly include (default 1). We may change this functionality
#     later, this is a bit of hacky way to do it. 
# [use_summon_openurl] default false. If true, will use OpenURL kev context
#     object passed back by summon to generate openurls, instead of creating
#     one ourself from individual data elements. summon openurl is decent,
#     but currently includes highlighting tags in title elements. Also note
#     it includes DC-type openurls, which we don't currently generate ourselves. 
# [lang]  Sent to summon as "s.l" param, see http://api.summon.serialssolutions.com/help/api/search/parameters/language
#         default nil. You may want to set to "en". 
#
#
# == Custom search params
#
# [:auth] Pass in `:auth => true` (or "true") to send headers to summon
# indicating an authorized user, for full search results. 
# [:summon_params]  Hash of key/value pairs to pass directly to summon. Just like
#                  fixed_params in configuration, but per-search. Can be
#                  used to directly trigger functionality not covered by
#                  the bento_search adapter. Values can be arrays where summon
#                  keys are repeatable. 
#
#
# == Tech notes
# We did not choose to use the summon ruby gem in general, we wanted more control
# than it offered (ability to use HTTPClient persistent connections, MultiJson
# for json parsing, etc). 
#
# However, we DO use that gem specifically for constructing authentication
# headers how summon wants it, see class at
# https://github.com/summon/summon.rb/blob/master/lib/summon/transport/headers.rb
#
# Language provided only in language_str not language_code, all that API gives
# us. We could try to reverse lookup from ISO code labels later if we want. 
class BentoSearch::SummonEngine
  include BentoSearch::SearchEngine
  
  extend HTTPClientPatch::IncludeClient
  include_http_client
  
  include ActionView::Helpers::OutputSafetyHelper # for safe_join
  
  @@hl_start_token = "$$BENTO_HL_START$$"
  @@hl_end_token = "$$BENTO_HL_END$$"
  
  def search_implementation(args)
    uri, headers = construct_request(args)
    
    results = BentoSearch::Results.new
    
    hash, response, exception = nil
    begin
      response = http_client.get(uri, nil, headers) 
      hash = MultiJson.load( response.body )
    rescue TimeoutError, HTTPClient::ConfigurationError, HTTPClient::BadResponseError, MultiJson::DecodeError, Nokogiri::SyntaxError => e
      exception = e
    end
    # handle some errors
    if (response.nil? || hash.nil? || exception ||
      (! HTTP::Status.successful? response.status))
      results.error ||= {}
      results.error[:exception] = e
      results.error[:status] = response.status if response
      
      return results
    end
        
    results.total_items = hash["recordCount"]
    
    hash["documents"].each do |doc_hash|
      item = BentoSearch::ResultItem.new
      
      item.unique_id      = first_if_present doc_hash["ID"]
      
      item.title          = format_title(doc_hash)
      
      item.link           = doc_hash["link"]
      # Don't understand difference between hasFullText and
      # isFullTextHit. ??. We'll use hasFullText for now, that's
      # the documented one. 
      item.link_is_fulltext = doc_hash["hasFullText"] 
      
      if configuration.use_summon_openurl      
        item.openurl_kev_co = doc_hash["openUrl"] # Summon conveniently gives us pre-made OpenURL
      end
            
      item.journal_title  = first_if_present doc_hash["PublicationTitle"]
      item.issn           = first_if_present doc_hash["ISSN"]
      item.isbn           = first_if_present doc_hash["ISBN"]
      item.doi            = first_if_present doc_hash["DOI"]
            
      item.start_page     = first_if_present doc_hash["StartPage"]
      item.end_page       = first_if_present doc_hash["EndPage"]

      if (pubdate = first_if_present doc_hash["PublicationDate_xml"])
        item.year         = pubdate["year"] 
      end
      item.volume         = first_if_present doc_hash["Volume"]
      item.issue          = first_if_present doc_hash["Issue"]
      
      if (pub = first_if_present doc_hash["Publisher_xml"])
        item.publisher    = pub["name"]
      end
      # if it's a dissertation, put the school in the 'publisher' field.
      # if we don't have one otherwise. 
      if (! item.publisher) && (school = first_if_present doc_hash["DissertationSchool_xml"])
        item.publisher    = school["name"]
      end
      
      (doc_hash["Author_xml"] || []).each do |auth_hash|
        a = BentoSearch::Author.new
        
        a.first           = name_normalize auth_hash["givenname"]
        a.last            = name_normalize auth_hash["surname"]
        a.middle          = name_normalize auth_hash["middlename"]
        
        a.display         = name_normalize auth_hash["fullname"]
        
        item.authors << a unless a.empty?
      end
      
      item.format         = normalize_content_type( first_if_present doc_hash["ContentType"] )
      if doc_hash["ContentType"]
        item.format_str     = doc_hash["ContentType"].join(", ")
      end
      
      item.language_str   = first_if_present doc_hash["Language"]
      
      if ( configuration.highlighting && configuration.snippets_as_abstract &&
        doc_hash["Snippet"] && doc_hash["Snippet"].length > 0 )
      
        item.abstract = handle_highlighting doc_hash["Snippet"].slice(0, configuration.max_snippets).join(" ")      
      else
        item.abstract       = first_if_present doc_hash["Abstract"]
      end
      
      results << item
    end
    
    
    return results
  end
  
  # Looks up a record by SerSol Id, engine.get( item.unique_id ) should return
  # item. 
  #
  # Returns a single BentoSearch::ResultItem, or raises BentoSearch::NotFound,
  # BentoSearch::TooManyFound, or other unspecified exception. 
  def get(id)
    # "ID" is an internal search field for Summon, not listed in our
    # own search_field_definitions, but it works. 
    results = search(id, :search_field => "ID")
    
    raise BentoSearch::NotFound.new("ID: #{id}") if results.length == 0
    raise BentoSearch::TooManyFound.new("ID: #{id}") if results.length == 0
    raise (results.error[:exception] || Exception.new(error.inspect)) if results.failed?
    
    return results.first
  end
  
  def first_if_present(array)
    array ? array.first : nil
  end
  
  
  # Normalize Summon Content-Type to our standardized
  # list. 
  #
  # This ends up losing useful distinctions Summon makes, however. 
  def normalize_content_type(summon_type)
    case summon_type
    when "Journal Article", "Book Review", "Trade Publication Article" then "Article"
    when "Audio Recording", "Music Recording" then "AudioObject"
    when "Book", "eBook" then "Book"
    when "Conference Proceedings" then :conference_paper
    when "Dissertation" then :dissertation
    when "Journal", "Newsletter" then :serial
    when "Photograph" then "Photograph"
    when "Video Recording" then "VideoObject"
    else nil
    end
  end
  
  def name_normalize(str)
    
    return nil if str.blank?
    
    str = str.strip
    
    return nil if str.blank? || str =~ /^[,:.]*$/
    
    return str
  end
  
  
  # returns two element array: [uri, headers]
  #
  # uri, headers = construct_request(args)
  def construct_request(args)
    # Query params in a hash with array values, becuase easiest
    # to generate auth headers that way. Value is array of values that
    # are NOT URI-encoded yet. 
    query_params = Hash.new {|h, k| h[k] = [] }
    
    # Add in fixed_params from config, and summon_params from search, if any.
    
    direct_params = (configuration.fixed_params || {}).merge( args[:summon_params] || {} ) 

    direct_params.each_pair do |key, value|
      [value].flatten.each do |v|
        query_params[key] << v
      end
    end  
    
    if args[:per_page]
      query_params["s.ps"] = args[:per_page]
    end
    if args[:page]
      query_params["s.pn"] = args[:page]
    end

    if args[:search_field]
      query_params['s.q'] = "#{args[:search_field]}:(#{summon_escape(args[:query])})"
    else
      query_params['s.q'] = summon_escape( args[:query] )
    end
    
    if (args[:sort] &&
        (defn = self.sort_definitions[args[:sort]]) &&
        (literal = defn[:implementation]))    
      query_params['s.sort'] =  literal
    end
    
    if args[:auth] == true
      query_params['s.role'] = "authenticated"
    end
    
    if configuration.highlighting
      query_params['s.hs'] = @@hl_start_token
      query_params['s.he'] = @@hl_end_token
    else 
      query_params['s.hl'] = "false"
    end
    
    if configuration.lang
      query_params["s.l"] = configuration.lang
    end
      
        
    headers = Summon::Transport::Headers.new(
      :access_id => configuration.access_id,
      :secret_key => configuration.secret_key,
      :accept => "json",
      :params => query_params,
      :url => configuration.base_url
      )
    
    
    query_string = query_params.keys.collect do |key|
      [query_params[key]].flatten.collect do |value|
        "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
      end
    end.flatten.join("&")
    
    uri = "#{configuration.base_url}?#{query_string}"
  
    return [uri, headers]
  end
    
  
  # Escapes special chars for Summon. Not entirely clear what
  # we have to escape where (or double escape sometimes?), but
  # we're just going to do a straight backslash escape of special
  # chars. 
  #
  # Does NOT do URI-escaping, that's a different step. 
  def summon_escape(string)
    # replace with backslash followed by original matched thing,
    # need to double backslash for ruby string literal makes
    # this ridiculously confusing, sorry. Block form of gsub
    # is the only thing that keeps it from being impossible.
    #
    # Do NOT escape double quotes, let people use them for
    # phrases! 
    #
    # While docs suggest you have to double-slash escape hyphens,
    # in fact doing so ruins ID: search, so we don't. 
    string.gsub(/([+&|!\(\){}\[\]^~*?\\:])/) do |match|
      "\\#{$1}"
    end
  end
  
  # If summon has put snippet highlighting tokens
  # in a field, we need to HTML escape the literal values,
  # while still using the highlighting tokens to put
  # HTML tags around highlighted terms.
  def handle_highlighting( str, options = {} )
    BentoSearch::Util.handle_highlight_tags(
      str,
      :start_tag => @@hl_start_token,
      :end_tag => @@hl_end_token,
      :enabled => configuration.highlighting,
      :strip => options[:strip]
      )          
  end
  
  # combine title and subtitle into one title, 
  def format_title(doc_hash)
    title          = first_if_present  doc_hash["Title"]  
    subtitle       = first_if_present doc_hash["Subtitle"] 
    
    if subtitle.present?
      title = "#{title}: #{subtitle}"
    end
    
    return handle_highlighting( title ) 
  end
    
  def self.required_configuration
    [:access_id, :secret_key]
  end
  
  def self.default_configuration
    {
      :base_url => "http://api.summon.serialssolutions.com/2.0.0/search",
      :highlighting => true,
      :snippets_as_abstract => true,
      :max_snippets => 1,
      :use_summon_openurl => false
    }
  end
  
  def max_per_page
    200
  end
  
  # Summon actually only supports relevancy sort, and pub year asc or desc.
  # we just expose relevance and pub year desc here. 
  def sort_definitions
    # implementation includes literal sersol value, but not yet
    # uri escaped, that'll happen at a later code point. 
    {
      "relevance" => {:implementation => nil}, # default
      "date_desc" => {:implementation => "PublicationDate:desc"}
      
    }
  end
  
  # Summon offers many more search fields than this. This is a subset
  # listed here. See http://api.summon.serialssolutions.com/help/api/search/fields
  # although those docs may not be up to date. 
  #
  # The AuthorCombined, TitleCombined, and SubjectCombined indexes
  # aren't even listed in the docs, but they are real. I think. 
  def search_field_definitions
      {
        "AuthorCombined"      => {:semantic => :author},
        "TitleCombined"       => {:semantic => :title},
        # SubjectTerms does not include TemporalSubjectTerms
        # or Keywords, sorry. 
        "SubjectTerms"        => {:semantic => :subject},
        # ISBN and ISSN do not include seperate EISSN and EISBN
        # fields, sorry. 
        "ISBN"                => {:semantic => :isbn},
        "ISSN"                => {:semantic => :issn},  
        "OCLC"                => {:semantic => :oclcnum},
        "PublicationSeriesTitle" => {}
      }
  end
  
  
  
end
