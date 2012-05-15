require 'httpclient'
require 'cgi'
require 'multi_json'

require 'action_view/helpers/sanitize_helper'

module BentoSearch
  #
  # https://developers.google.com/books/docs/v1/using
  # https://developers.google.com/books/docs/v1/reference/volumes#resource  
  class GoogleBooksEngine
    include BentoSearch::SearchEngine
    include ActionView::Helpers::SanitizeHelper
    
    # class-level HTTPClient for maintaining persistent HTTP connections
    class_attribute :http_client
    self.http_client = HTTPClient.new
    
    class_attribute :base_url
    self.base_url = "https://www.googleapis.com/books/v1/"
    
    # used for testing only, GBS does allow some limited rate
    # of searches without a key. 
    class_attribute :suppress_key
    self.suppress_key = false
    
    
    def search(*arguments)
      arguments = parse_search_arguments(*arguments)
      
      query_url = base_url + "volumes?q=#{CGI.escape  arguments[:query]}"
      unless suppress_key
        query_url += "&key=#{configuration.api_key}"
      end
      if arguments[:per_page]
        query_url += "&maxResults=#{arguments[:per_page]}"
      end
      if arguments[:start]
        query_url += "&startIndex=#{arguments[:start]}"
      end
      
      results = Results.new
      
      begin
        response = http_client.get(query_url )
        json = MultiJson.load( response.body )
      ensure
        # Trap json parse error, but also check for bad http
        # status, or error reported in the json. In any of those cases
        # return results obj with error status. 
        #                 
        if ( (! HTTP::Status.successful? response.status) ||
             (json && json["error"]))

         results.error = {}
         results.error[:status] = response.status if response
         if json && json["error"] && json["error"]["errors"] && json["error"]["errors"].kind_of?(Array)
           results.error[:message] = json["error"]["errors"].first.values.join(", ")
         end
         results.error[:error_info] = json["error"] if json && json.respond_to?("[]")
         
         # escape early!
         return results
        end                        
      end
      
      results.total_items = json["totalItems"]
      results.start = arguments[:start] || 0
      results.per_page = arguments[:per_page] || 10
      
      json["items"].each do |j_item|
        j_item = j_item["volumeInfo"] if j_item["volumeInfo"]
        
        item = ResultItem.new
        results << item
        
        item.title          = j_item["title"] 
        item.subtitle       = j_item["subtitle"] 
        item.link           = j_item["canonicalVolumeLink"]        
        item.abstract       = sanitize j_item["description"]        
        item.year_published = get_year j_item["publishedDate"]         
        item.format         = if j_item["printType"] == "MAGAZINE"
                              :serial
                            else
                              "Book"
                            end        
      end
      
      
      return results
    end
    
    
    protected
    
    def self.required_configuration
      ["api_key"]
    end
    
    def self.max_per_page
      100
    end
    
    
    def get_year(iso8601)
      return nil if iso8601.blank?
      
      if iso8601 =~ /^(\d{4})/
        return $1.to_i
      end
      return nil            
    end
        
  end
end
