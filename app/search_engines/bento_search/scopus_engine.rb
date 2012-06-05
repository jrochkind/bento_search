require 'cgi'

module BentoSearch
  # Uses the Scopus SciVerse REST API. You need to be a Scopus customer
  # to access. http://api.elsevier.com
  # 
  # ToS: http://www.developers.elsevier.com/devcms/content-policies
  # "Federated Search" use case. 
  # Also: http://www.developers.elsevier.com/cms/apiserviceagreement
  #
  # Register for an API key at "Register New Site" at http://developers.elsevier.com/action/devnewsite
  # You will then need to get server IP addresses registered with Scopus too, 
  # apparently by emailing directly to dave.santucci at elsevier dot com.  
  #    
  # Scopus API Docs:   
  # * http://www.developers.elsevier.com/devcms/content-api-search-request
  # * http://www.developers.elsevier.com/devcms/content/search-fields-overview
  # Other API's in the suite not being used by this code at present: 
  # * http://www.developers.elsevier.com/devcms/content-api-retrieval-request
  # * http://www.developers.elsevier.com/devcms/content-api-metadata-request
  #
  # Support: Integration@scopus.com
  # 
  class ScopusEngine
    include BentoSearch::SearchEngine
    
    extend HTTPClientPatch::IncludeClient
    include_http_client
    
    def search(args)            
      
      response = http_client.get( scopus_url(args) , nil,
        # HTTP headers. 
        {"X-ELS-APIKey" => configuration.api_key, 
        "X-ELS-ResourceVersion" => "XOCS",
        "Accept" => "application/atom+xml"}
      )
      
      
      return response
    end
    
    
    def self.required_configuration
      ["api_key"]
    end
    
    def self.default_configuration
      { 
        :base_url => "http://api.elsevier.com/",
        :cluster => "SCOPUS"
      }
    end
    
    def self.search_field_definitions
      {
        "AUTH"        => {:semantic => :author},
        "TITLE"       => {:semantic => :title},
        # controlled and author-assigned keywords
        "KEY"         => {:semantic => :subject},
        "ISBN"        => {:semantic => :isbn},
        "ISSN"        => {:semantic => :issn},              
      }
    end
    
    protected
    
    def scopus_url(args)
      query = args[:query]
      
      if args[:search_field]
        query = "#{args[:search_field]}(#{query})"
      end
      
      query = "#{configuration.base_url.chomp("/")}/content/search/index:#{configuration.cluster}?query=#{CGI.escape(query)}"
      
      query += "&count=#{args[:per_page]}" if args[:per_page]
      
      return query
    end
    
  end
end
