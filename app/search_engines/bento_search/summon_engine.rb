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
#     of values. For instance, to exclude Newspaper Articles and Books
#     from all search results, in config:
#         :fixed_params => {"s.fvf" => ["ContentType,Newspaper Article,true", "ContentType,Book,true"]
#     Note that values are NOT URI escaped in config, code will take care
#     of that for you. You could also fix "s.role" to 'authenticated' using
#     this mechanism, if you restrict all access to your app to authenticated
#     affiliated users. 
#
# == Custom search params
#
# Pass in `:auth => true` (or "true") to send headers to summon
# indicating an authorized user, for full search results. 
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
class BentoSearch::SummonEngine
  include BentoSearch::SearchEngine
  
  extend HTTPClientPatch::IncludeClient
  include_http_client
  
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
      results << doc_hash
    end
    
    
    return results
  end
  
  
  # returns two element array: [uri, headers]
  #
  # uri, headers = construct_request(args)
  def construct_request(args)
    # Query params in a hash with array values, becuase easiest
    # to generate auth headers that way. Value is array of values that
    # are NOT URI-encoded yet. 
    query_params = Hash.new {|h, k| h[k] = [] }
    
    # Add in fixed params from config, if any. 
    if configuration.fixed_params
      configuration.fixed_params.each_pair do |key, value|
        [value].flatten.each do |v|
          query_params[key] << v
        end
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
        (defn = self.class.sort_definitions[args[:sort]]) &&
        (literal = defn[:implementation]))    
      query_params['s.sort'] =  literal
    end
    
    if args[:auth] == true
      query_params['s.role'] = "authenticated"
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
    string.gsub(/([+\-&|!\(\){}\[\]^~*?\\:])/) do |match|
      "\\#{$1}"
    end
  end
    
  def self.required_configuration
    [:access_id, :secret_key]
  end
  
  def self.default_configuration
    {
      :base_url => "http://api.summon.serialssolutions.com/2.0.0/search"
    }
  end
  
  def self.max_per_page
    200
  end
  
  # Summon actually only supports relevancy sort, and pub year asc or desc.
  # we just expose relevance and pub year desc here. 
  def self.sort_definitions
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
  def self.search_field_definitions
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
