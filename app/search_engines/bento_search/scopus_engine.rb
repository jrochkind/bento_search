require 'cgi'
require 'nokogiri'

require 'http_client_patch/include_client'
require 'httpclient'
module BentoSearch
  # TODO: Sorting, Facets. 
  #
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
    
    def search_implementation(args)        
      results = Results.new
      
      xml, response, exception = nil, nil, nil
      
      begin
        response = http_client.get( scopus_url(args) , nil,
          # HTTP headers. 
          {"X-ELS-APIKey" => configuration.api_key, 
          "X-ELS-ResourceVersion" => "XOCS",
          "Accept" => "application/atom+xml"}
        )
        xml = Nokogiri::XML(response.body)
      rescue TimeoutError, HTTPClient::ConfigurationError, HTTPClient::BadResponseError, Nokogiri::SyntaxError  => e
        exception = e        
      end
      # handle errors
      if (response.nil? || xml.nil? || exception || 
          (! HTTP::Status.successful? response.status) ||
          xml.at_xpath("service-error")
          )
        results.error ||= {}
        results.error[:exception] = e
        results.error[:status] = response.status if response
        # keep from storing the entire possibly huge response as error
        # but sometimes it's an error message. 
        results.error[:error_info] = xml.at_xpath("service_error") if xml
        return results
      end                  
      
      results.total_items = node_text xml.at_xpath("//opensearch:totalResults", xml_ns)
      
      xml.xpath("//atom:entry", xml_ns).each do | entry |

        results << (item = ResultItem.new)        
        item.link           = node_text entry.at_xpath("prism:url", xml_ns)
        item.title          = node_text entry.at_xpath("dc:title", xml_ns)
        item.journal_title  = node_text entry.at_xpath("prism:publicationName", xml_ns)
        item.issn           = node_text entry.at_xpath("prism:issn", xml_ns)
        item.volume         = node_text entry.at_xpath("prism:volume", xml_ns)
        item.issue          = node_text entry.at_xpath("prism:issueIdentifier", xml_ns)
        item.doi            = node_text entry.at_xpath("prism:doi", xml_ns)
        
        # pages might be in startingPage/endingPage OR in pageRange
        if (start = entry.at_xpath("prism:startingPage", xml_ns))
          item.start_page = start.text.to_i
          if ( epage = entry.at_xpath("prism:endingPage", xml_ns))
            item.end_page = epage.text.to_i
          end
        elsif (range = entry.at_xpath("prism:pageRange", xml_ns))
          (spage, epage) = *range.text().split("-")
          item.start_page = spage
          item.end_page = epage
        end
        
        # Authors might be in atom:authors seperated by |, or just
        # a single one in dc:creator
        if (authors = entry.at_xpath("atom:authors", xml_ns))
          authors.text.split("|").each do |author|
            item.authors << Author.new(:display => author.strip)
          end
        elsif (author = entry.at_xpath("dc:creator", xml_ns))
          item.authors << Author.new(:display => author.text.strip)
        end
        
        # Format we're still trying to figure out how Scopus API
        # delivers it. Here is at at least one way.
        if (doctype = entry.at_xpath("atom:subtype", xml_ns))
          item.format = doctype_map(doctype.text)
        end
        
      end
      
      return results
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
    
    def self.default_per_page
      25
    end
    
    protected
    
    # returns nil if passed in nil, otherwise
    # returns nokogiri text()
    def node_text(node)
      return nil if node.nil?
      
      return node.text()
    end
    
    def xml_ns
      {"opensearch" => "http://a9.com/-/spec/opensearch/1.1/",
       "prism"      => "http://prismstandard.org/namespaces/basic/2.0/",
       "dc"         => "http://purl.org/dc/elements/1.1/",
       "atom"       => "http://www.w3.org/2005/Atom"}
     end
    
    # Maps from Scopus "doctype" as listed at http://www.developers.elsevier.com/devcms/content/search-fields-overview
    # and delivered in the XML response as atom:subtype. 
    # Maps to our own internal formats as documented in ResultItem#format
    # Returns nil if can't map. 
    def doctype_map(doctype)
      { "ar" => "Article",
        "ip" => "Article",
        "bk" => "Book",
        "bz" => "Artilce"
      }[doctype.to_s]
    end
     
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
