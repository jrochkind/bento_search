# encoding: UTF-8

require 'nokogiri'
require 'httpclient'
require 'multi_json'
require 'http_client_patch/include_client'


#
# For EBSCO Discovery Service. You will need a license to use. 
#
# == Required Configuration
#
# user_id, password: As given be EBSCO for access to EDS API (may be an admin account in ebscoadmin? Not sure). 
# profile: As given by EBSCO, might be "edsapi"?
#
# == Highlighting
#
# EDS has a query-in-context highlighting feature. It is used by defualt, set 
# config 'highlighting' to false to disable. 
# If turned on, you may get <b class="bento_search_highlight"> tags
# in title and abstract output if it's on, marked html_safe.  
#
# If highlighting is on, since the abstract will be marked html safe, the
# view layer won't be able to safely truncate it. In fact, it's very hard
# to do here too, but we do it anyway, by default to approx configuration
# truncate_highlighted num of chars (default 280). Set to nil if you don't
# want this. 
#
# == Linking
#
# The link to record in EBSCO interface delivered as "PLink" will be listed
# as record main link. 
#
# Any links listed under <CustomLinks> will be listed as other_links, using
# configured name provided by EBSCO for CustomLink.
#
# EDS Response does not have sufficient metadata for us to generate an OpenURL
# ourselves. However, in our testing, the first/only CustomLink was an
# an OpenURL. If configuration.assume_first_custom_link_openurl is
# true (as is default), it will be used to create an OpenURL link. However, in
# our testing, many records don't have this at all. **Note** Ask EBSCO support
# to configure your profile so OpenURLs are ALWAYS included for all records, not
# just records with no EBSCO fulltext, to ensure bento_search can get the
# openurl. 
#
# As always, you can customize links and other_links with Item Decorators. 
#
# == Technical Notes and Difficulties
#
# This API is enormously difficult to work with. Also the response is very odd
# to deal with and missing some key elements. We quite possibly got something
# wrong or non-optimal in this implementation, but we did our best. 
#
# Auth issues may make this slow -- you need to spend a (not too speedy) HTTP
# request making a session for every new end-user -- as we have no way to keep
# track of end-users, we do it on every request in this implementation. 
#
# Responses don't include much metadata -- we don't actually have journal title,
# volume, issue, etc.  We probably _could_ parse it out of the OpenURL that's
# there depending on your profile configuration, but we're not right now.
# Instead we're using the chunk of user-displayable citation/reference it does
# give us (which is very difficult to parse into something usable already),
# and a custom Decorator to display that instead of normalized citation
# made from individual elements. 
#
# EBSCO says they plan to improve some of these issues in a September 2012 release. 
#
# Title and abstract data seems to be HTML with tags and character entities and
# escaped special chars. We're trusting it and passing it on as html_safe. 
#
# Paging can only happen on even pages, with 'page' rather than 'start'. But
# you can pass in 'start' to bento_search, it'll be converted to closest page. 
#
# == Authenticated Users
#
# EDS allows searches by unauthenticated users, but the results come back with 
# weird blank hits. In such a case, the BentoSearch adapter will return
# records with virtually no metadata, but a title e
# (I18n at bento_search.eds.record_not_available ). Also no abstracts
# are available from unauth search. 
#
# By default the engine will search as 'guest' unauth user. But config
# 'auth' key to true to force all searches to auth (if you are protecting your
# app) or pass :auth => true as param into #search method.  
#
# == EDS docs:
# 
# * Console App to demo requests: https://eds-api.ebscohost.com/Console   
# * EDS Wiki: http://edswiki.ebscohost.com/EDS_API_Documentation
# * You'll need to request an account to the EDS wiki, see: http://support.ebsco.com/knowledge_base/detail.php?id=5990
# 
class BentoSearch::EdsEngine
  include BentoSearch::SearchEngine
  
  extend HTTPClientPatch::IncludeClient
  include_http_client
    
  AuthHeader          = "x-authenticationToken"
  SessionTokenHeader  = "x-sessionToken"

  @@remembered_auth = nil
  @@remembered_auth_lock = Mutex.new
  # Class variable to save current known good auth
  # uses a mutex to be threadsafe. sigh. 
  def self.remembered_auth
    @@remembered_auth_lock.synchronize do      
      @@remembered_auth
    end
  end
  # Set class variable with current known good auth. 
  # uses a mutex to be threadsafe. 
  def self.remembered_auth=(token)
    @@remembered_auth_lock.synchronize do
      @@remembered_auth = token
    end
  end
  
  # an object that includes some Rails helper modules for
  # text handling. 
  def helper
    unless @helper
      @helper = Object.new
      @helper.extend ActionView::Helpers::TextHelper # for truncate
      @helper.extend ActionView::Helpers::OutputSafetyHelper # for safe_join
    end
    return @helper
  end
  
  
  def self.required_configuration
    %w{user_id password profile}
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
  
  def construct_search_url(args)
    query = "AND,"
    if args[:search_field]
      query += "#{args[:search_field]}:"
    end
    # Can't have any commas in query, it turns out, although
    # this is not documented. 
    query += args[:query].gsub("/\,/", "")
    
    url = "#{configuration.base_url}search?view=detailed&query=#{CGI.escape query}"
    
    url += "&searchmode=#{CGI.escape configuration.search_mode}"
    
    url += "&highlight=#{configuration.highlighting ? 'y' : 'n' }"
    
    if args[:per_page]
      url += "&resultsperpage=#{args[:per_page]}"
    end
    if args[:page]
      url += "&pagenumber=#{args[:page]}"
    end
    
    if args[:sort]
      if (defn = self.sort_definitions[args[:sort]]) &&
           (value = defn[:implementation] )
        url += "&sort=#{CGI.escape value}"
      end
    end
    
    
    return url
  end
  
  
  
  def search_implementation(args)
    results = BentoSearch::Results.new
    
    end_user_auth = authenticated_end_user? args
    
    begin
      with_session(end_user_auth) do |session_token|
                        
        url = construct_search_url(args)
                
        response = get_with_auth(url, session_token)
        
        results = BentoSearch::Results.new
        
        if (hits_node = at_xpath_text(response, "./SearchResponseMessageGet/SearchResult/Statistics/TotalHits"))          
          results.total_items = hits_node.to_i
        end
        
        response.xpath("./SearchResponseMessageGet/SearchResult/Data/Records/Record").each do |record_xml|
          item = BentoSearch::ResultItem.new
          
          item.title = prepare_eds_payload( element_by_group(record_xml, "Ti"), true )
          if item.title.nil? && ! end_user_auth
            item.title = I18n.translate("bento_search.eds.record_not_available")
          end
          
          item.abstract = prepare_eds_payload( element_by_group(record_xml, "Ab"), true )

          # Believe it or not, the authors are encoded as an escaped
          # XML-ish payload, that we need to parse again and get the
          # actual authors out of. WTF. Thanks for handling fragments
          # nokogiri. 
          author_mess = element_by_group(record_xml, "Au")
          author_xml = Nokogiri::XML::fragment(author_mess)
          author_xml.xpath(".//searchLink").each do |author_node|
            item.authors << BentoSearch::Author.new(:display => author_node.text)
          end
          
          
          # PLink is main inward facing EBSCO link, put it as
          # main link. 
          if direct_link = record_xml.at_xpath("./PLink")
              item.link = direct_link.text
          end
          
          # Other links may be found in CustomLinks, it seems like usually
          # there will be at least one, hopefully the first one is the OpenURL?
          record_xml.xpath("./CustomLinks/CustomLink").each do |custom_link|
            item.other_links << BentoSearch::Link.new(
              :url => custom_link.at_xpath("./Url").text,
              :label => custom_link.at_xpath("./Name").text
              )
          end
          
          if (configuration.assume_first_custom_link_openurl &&
            (first = record_xml.xpath "./CustomLinks/CustomLink" ) &&
            (node = first.at_xpath "./Url" )
          )
          
            openurl = node.text
            
            index = openurl.index('?')
            item.openurl_kev_co = openurl.slice index..(openurl.length) if index            
          end

          # Format. 
          item.format_str = at_xpath_text record_xml, "./Header/PubType"
          # Can't find a list of possible PubTypes to see what's there to try
          # and map to our internal controlled vocab. oh wells. 
          
          
          
          # We have a single blob of human-readable citation, that's also
          # littered with XML-ish tags we need to deal with. We'll save
          # it in a custom location, and use a custom Decorator to display
          # it. Sorry it's way too hard for us to preserve <highlight>
          # tags in this mess, they will be lost. Probably don't
          # need highlighting in source anyhow. 
          citation_mess = element_by_group(record_xml, "Src")
          citation_txt = Nokogiri::XML::fragment(citation_mess).text
          # But strip off some "count of references" often on the end
          # which are confusing and useless. 
          item.custom_data["citation_blob"] = citation_txt.gsub(/ref +\d+ +ref\.$/, '')           
                              
          item.extend CitationMessDecorator
          
          results << item
        end        
      end
      
      return results      
    rescue EdsCommException => e
      results.error ||= {}
      results.error[:exception] = e
      results.error[:http_status] = e.http_status
      results.error[:http_body] = e.http_body
      return results
    end
    
  end
  
  # Difficult to get individual elements out of an EDS XML <Record>
  # response, requires weird xpath, so we do it for you. 
  # element_by_group(nokogiri_element, "Ti")
  #
  # Returns string or nil
  def element_by_group(noko, group)
    at_xpath_text(noko, "./Items/Item[child::Group[text()='#{group}']]/Data")
  end
  
  # Wraps calls to the EDS api with CreateSession and EndSession requests
  # to EDS. Will pass sessionID in yield from block.
  #
  # Second optional arg is whether this is an authenticated user, else
  # guest access will be used. 
  #
  #     with_session(true) do |session_token|
  #       # can make more requests using session_token,
  #       # EndSession will be called for you at end of block. 
  #     end
  def with_session(auth = false, &block)
    auth_token = self.class.remembered_auth    
    if auth_token.nil?
      auth_token = self.class.remembered_auth = get_auth_token
    end
    
            
    create_url = "#{configuration.base_url}createsession?profile=#{configuration.profile}&guest=#{auth ? 'n' : 'y'}"    
    response_xml = get_with_auth(create_url)    
    
    session_token = nil
    unless response_xml && (session_token = at_xpath_text(response_xml, "//SessionToken"))  
      e = EdsCommException.new("Could not get SessionToken")      
    end
                
    begin    
      block.yield(session_token)
    ensure      
      if auth_token && session_token   
        end_url = "#{configuration.base_url}endsession?sessiontoken=#{CGI.escape session_token}"
        response_xml = get_with_auth(end_url)        
      end
    end
    
  end
  
  # if the xpath responds, return #text of it, else nil. 
  def at_xpath_text(noko, xpath)
    node = noko.at_xpath(xpath)
    
    if node.nil?
      return node
    else
      return node.text
    end
  end
  
  # If EDS has put highlighting tags
  # in a field, we need to HTML escape the literal values,
  # while still using the highlighting tokens to put
  # HTML tags around highlighted terms.
  #
  # Second param, if to assume EDS literals are safe HTML, as they
  # seem to be. 
  def prepare_eds_payload(str, html_safe = false)
    return str if str.blank?
    
    unless configuration.highlighting
      str = str.html_safe if html_safe  
      return str
    end
        
    parts = 
    str.split(%r{(</?highlight>)}).collect do |substr|
      case substr
      when "<highlight>" then "<b class='bento_search_highlight'>".html_safe
      when "</highlight>" then "</b>".html_safe
      # Yes, EDS gives us HTML in the literals, we're choosing to trust it. 
      else substr.html_safe
      end
    end
    
    
    
    
    
    # Crazy ass method to truncate without getting in the middle of our
    # html tags. This is wacky hacky, yeah. 
    if configuration.truncate_highlighted
      remainingLength = configuration.truncate_highlighted
      in_tag = false
      elipses_added = false
      
      truncated_parts = []
      parts.each do |substr|
        if remainingLength <=0 && ! in_tag
          truncated_parts << "..."
          break
        end
        
        if substr =~ /^<b.*\>$/
          truncated_parts << substr
          in_tag = true
        elsif substr == "</b>"
          truncated_parts << substr
          in_tag = false
        elsif ((remainingLength - substr.length) > 0) || in_tag
          truncated_parts << substr
        else
          truncated_parts << helper.truncate(substr, :length => remainingLength, :separator  => ' ')
          break
        end
        
        remainingLength = remainingLength - substr.length
      end
      
      parts = truncated_parts
    end

    
    return helper.safe_join(parts, '')        
  end
  
  # Give it a url pointing at EDS API.
  # Second arg must be a session_token if EDS request requires one. 
  # It will 
  # * Make a GET request
  # * with memo-ized auth token added to headers
  # * for XML, with all namespaces removed!
  # * Parse JSON into a hash and return hash
  # * Try ONCE more to get if EBSCO says bad auth token
  # * Raise an EdsCommException if can't auth after second try,
  #   or other error message, or JSON can't be parsed. 
  def get_with_auth(url, session_token = nil)
    auth_token = self.class.remembered_auth
    unless auth_token
      auth_token = self.class.remembered_auth = get_auth_token
    end
    
    response = nil
    response_xml = nil
    caught_exception = nil
                
    begin
      headers = {AuthHeader => auth_token, 'Accept' => 'application/xml'}
      headers[SessionTokenHeader] = session_token if session_token
      
      s_time = Time.now
      response = http_client.get(url, nil, headers)
      Rails.logger.debug("EDS timing GET: #{Time.now - s_time}:#{url}")
      
      response_xml = Nokogiri::XML(response.body)
      response_xml.remove_namespaces!
      
      if (at_xpath_text(response_xml, "//ErrorNumber") == "104") || (at_xpath_text(response_xml, "//ErrorDescription") == "Auth Token Invalid")
        # bad auth, try again just ONCE
        Rails.logger.debug("EDS auth failed, getting auth again")
        
        headers[AuthHeader] = self.class.remembered_auth = get_auth_token
        response = http_client.get(url, nil, headers)
        response_xml = Nokogiri::XML(response.body)
        response_xml.remove_namespaces!        
      end            
    rescue TimeoutError, HTTPClient::ConfigurationError, HTTPClient::BadResponseError, Nokogiri::SyntaxError => e
      caught_exception = e
    end
    
    if response.nil? || response_xml.nil? || caught_exception ||  (! HTTP::Status.successful? response.status)
      exception = EdsCommException.new("Error fetching URL: #{caught_exception.message if caught_exception} : #{url}")
      if response
        exception.http_body = response.body
        exception.http_status = response.status
      end
      raise exception
    end
        
    return response_xml
  end
  
  
  # Has to make an HTTP request to get EBSCO's auth token. 
  # returns the auth token. We aren't bothering to keep
  # track of the expiration ourselves, can't neccesarily trust
  # it anyway. 
  #
  # Raises an EdsCommException on error. 
  def get_auth_token    
    # Can't send params as form-encoded, actually need to send a JSON or XML
    # body, argh. 
    
    body = <<-EOS
      {
        "UserId":"#{configuration.user_id}",
        "Password":"#{configuration.password}"
      }
    EOS
    
    s_time = Time.now
    response = http_client.post(configuration.auth_url, body, {'Accept' => "application/json", "Content-type" => "application/json"})
    Rails.logger.debug("EDS timing AUTH: #{Time.now - s_time}s")    
    
    unless HTTP::Status.successful? response.status
      raise EdsCommException.new("Could not get auth", response.status, response.body)
    end
        
    response_hash = nil
    begin
      response_hash = MultiJson.load response.body
    rescue MultiJson::DecodeError
    end
  
    unless response_hash.kind_of?(Hash) && response_hash.has_key?("AuthToken")
      raise EdsCommException.new("AuthToken not found in auth response", response.status, response.body)
    end
    
    return response_hash["AuthToken"]        
  end
  
  def self.default_configuration
    {
      :auth_url => 'https://eds-api.ebscohost.com/authservice/rest/uidauth',
      :base_url => "http://eds-api.ebscohost.com/edsapi/rest/",
      :highlighting => true,
      :truncate_highlighted => 280,
      :assume_first_custom_link_openurl => true,
      :search_mode => 'all' # any | bool | all | smart ; http://support.epnet.com/knowledge_base/detail.php?topic=996&id=1288&page=1
    }
  end
  
  def sort_definitions       
    {        
      "date_desc"     => {:implementation => "date"},
      "relevance"     => {:implementation => "relevance" }
      #       "date_asc"      => {:implementaiton => "date2"}
    }
  end
  
  def search_field_definitions
    {
      "TX" => {:semantic => :all},
      "AU" => {:semantic => :author},
      "TI" => {:semantic => :title},
      "SU" => {:semantic => :subject},
      "SO" => {}, # source, journal name
      "AB" => {}, # abstract
      "IS" => {:semantic => :issn},
      "IB" => {:semantic => :isbn},
    }
  end
  
  # an exception talking to EDS api. 
  # there's a short reason in #message, but also
  # possibly an http_status and http_body copied
  # from error EDS response. 
  class EdsCommException < Exception
    attr_accessor :http_status, :http_body
    def initialize(message, status = nil, body = nil)
      super(message)
      self.http_status = status
      self.http_body = body
    end
  end
  
  
  # A built-in decorator alwasy applied, that over-rides
  # the ResultItem#published_in display method to use our mess blob
  # of human readable citation, since we don't have individual elements
  # to create it from in a normalized way. 
  module CitationMessDecorator
    def published_in
      custom_data["citation_blob"]
    end
  end
  
end
