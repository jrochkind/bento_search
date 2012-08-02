# encoding: UTF-8

require 'nokogiri'
require 'multi_json'
require 'httpclient'
require 'http_client_patch/include_client'


#
# For EBSCO Discovery Service. You will need a license to use. 
#
# == Required Configuration
#
# user_id, password: As given be EBSCO for access to EDS API (may be an admin account in ebscoadmin? Not sure). 
# profile: As given by EBSCO, might be "edsapi"?
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
  
  
  def self.required_configuration
    %w{user_id password profile}
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
    response_hash = get_with_auth(create_url)    
    
    unless response_hash && response_hash.has_key?("SessionToken")  
      e = EdsCommException.new("Could not get SessionToken")      
    end
        
    session_token = response_hash["SessionToken"]
    
    begin    
      block.yield(session_token)
    ensure      
      if auth_token && session_token   
        end_url = "#{configuration.base_url}endsession?sessiontoken=#{CGI.escape session_token}"
        response_hash = get_with_auth(end_url)        
      end
    end
    
  end
  
  # Give it a url pointing at EDS API.
  # Second arg must be a session_token if EDS request requires one. 
  # It will 
  # * Make a GET request
  # * with memo-ized auth token added to headers
  # * for JSON
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
    response_hash = nil
    caught_exception = nil
                
    begin
      headers = {AuthHeader => auth_token, 'Accept' => 'application/json'}
      headers[SessionTokenHeader] = session_token if session_token
      response = http_client.get(url, nil, headers)
      response_hash = MultiJson.load(response.body)
      
      if response_hash["ErrorNumber"] == "104" || response_hash["ErrorDescription"] == "Auth Token Invalid"
        # bad auth, try again just ONCE
        headers[AuthHeader] = self.class.remembered_auth = get_auth_token
        response = http_client.get(url, nil, headers)
        response_hash = MultiJson.load(response.body)        
      end            
    rescue MultiJson::DecodeError => e
      caught_exception = e
    end
    
    if response.nil? || response_hash.nil? || caught_exception ||  (! HTTP::Status.successful? response.status)
      require 'debugger'
      debugger
      exception = EdsCommException.new("Error fetching URL: #{caught_exception.message if caught_exception} : #{url}")
      if response
        exception.http_body = response.body
        exception.http_status = response.status
      end
      raise exception
    end
        
    return response_hash
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
    
    
    response = http_client.post(configuration.auth_url, body, {'Accept' => "application/json", "Content-type" => "application/json"})
        
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
      :base_url => "http://eds-api.ebscohost.com/edsapi/rest/"
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
  
  
end
