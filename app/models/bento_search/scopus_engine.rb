module BentoSearch
  # Uses the Scopus SciVerse REST API. You need to be a Scopus customer
  # to access. http://api.elsevier.com
  # 
  # ToS: http://www.developers.elsevier.com/devcms/content-policies
  # "Federated Search" use case. 
  # Also: http://www.developers.elsevier.com/cms/apiserviceagreement
  #
  # Register for an API key at "Register New Site" at http://developers.elsevier.com/action/devnewsite
  # You will then need to get server IP addresses registered with Scopus too, email?
  #    
  # Scopus API Docs:   
  # * http://www.developers.elsevier.com/devcms/content-api-search-request
  # * http://www.developers.elsevier.com/devcms/content-api-retrieval-request
  # * http://www.developers.elsevier.com/devcms/content-api-metadata-request
  #
  # Support: Integration@scopus.com
  # 
  class ScopusEngine
    
    def search(args)            
      
    end
    
    
    def self.required_configuration
      ["api_key"]
    end
    
    def self.default_configuration
      { 
        :base_url => "http://api.elsevier.com",
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
    
  end
end
