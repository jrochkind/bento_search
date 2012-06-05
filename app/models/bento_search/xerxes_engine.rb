require 'uri'
require 'nokogiri'
require 'openurl'

require 'httpclient'
require 'http_client_patch/include_client'

module BentoSearch
  # a **very limited and hacky** bento search engine for the Xerxes Metalib
  # front-end. Probably not suitable for real production use, just a demo,
  # and used for testing. Does not support pagination, or fielded searching.
  # will do a new Metalib search every time you call it, which will be slow. 
  #
  # Machine running this code needs to have IP-address authorization
  # to search xerxes. 
  #
  # jrochkind is using it for his article search provider comparison testing
  # instrument.
  
  class XerxesEngine
    include BentoSearch::SearchEngine
    
    extend HTTPClientPatch::IncludeClient
    include_http_client
    
    # also optional configuration
    # [xerxes_context]
    #   will send as 'context' query param to xerxes, for analytics
    def self.required_configuration
      ["base_url", "databases"]
    end
    
    def search_implementation(arguments)
      
      # We're gonna have to do a search 'screen scrape' style, then refresh it
      # until it's ready, and then request format=xerxes when it's ready
      # to get XML. A bit hacky. 
      
      request_url = xerxes_search_url(arguments)
      
      
      response = http_client.head request_url
      
      # It's supposed to be a redirect
      unless HTTP::Status.redirect?(response.status) && response.headers["Location"]
        r = Results.new
        r.error ||= {}
        r.error["status"] = response.status
        r.error["message"] = "Xerxes did not return expected 302 redirect"
        
        return r
      end
      
      # Okay, now fetch the redirect, have to change it to an absolute
      # URI cause Xerxes semi-illegally returns a relative one.
      refreshes = 0
      results_url = nil
      status_url = (URI.parse(request_url) + response.headers["Location"]).to_s
      while ( refreshes < 5 )
        # cause of VCR, can't request the exact same URL twice
        # with different results. Add `try` on the end. 
        response = http_client.get( status_url + "&try=#{refreshes}")
          
        # Okay, have to follow the meta-refresh
        html = Nokogiri::HTML( response.body )
        
        if HTTP::Status.redirect? response.status
          # Okay, redirect means we're done with status and
          # we've got actual results url
          results_url = URI.parse(request_url) + response.headers["Location"]
          break
        end        
        
        if ( refresh = html.css("meta[http-equiv='refresh']")  )
          wait = configuration.lookup!("refresh_wait", (refresh.attribute("content").value.to_i if refresh.attribute("content")))  
          # wait how long Xerxes asked before refreshing.
          refreshes += 1
          sleep wait
        end
      end
          
      results = Results.new
      
      # any errors?
      if results_url.nil? && refreshes >= 5
        results.error ||= {}
        results.error["message"] = "#{refreshes} refreshes exceeded maximum"
        return results
      end
      
      # Okay, fetch it as format xerxes
      
      xml = Nokogiri::XML( http_client.get(results_url.to_s + "&amp;format=xerxes").body ) 
      
      results = Results.new
      
      xml.xpath("//results/records/record").each do |record|
        item = ResultItem.new
        results << item
        
        item.title = node_text record.at_xpath("xerxes_record/title")
        
        xerxes_fmt_str = node_text(record.at_xpath("xerxes_record/format")).downcase
        
        item.format = if xerxes_fmt_str.include?("article")
          "Article"
        elsif xerxes_fmt_str.include?("Book")
          "Book"
        else
          nil
        end
                
        item.link           = node_text record.at_xpath("xerxes_record/links/link[@type='original_record']/url")
        
        item.year           = node_text record.at_xpath("xerxes_record/year")
        item.volume         = node_text record.at_xpath("xerxes_record/volume")
        item.issue          = node_text record.at_xpath("xerxes_record/issue")
        item.start_page     = node_text record.at_xpath("xerxes_record/start_page")
        item.end_page       = node_text record.at_xpath("xerxes_record/end_page")                        
        
        item.abstract = node_text(record.at_xpath("xerxes_record/abstract") || record.at_xpath("xerxes_record/summary"))
        
        item.openurl_kev_co = node_text record.at_xpath("openurl_kev_co")
        
        # have to get journal title out of openurl, sorry        
        if item.openurl_kev_co
          openurl = OpenURL::ContextObject.new_from_kev(   item.openurl_kev_co )
          if openurl && openurl.referent && openurl.referent.format == "journal"
            item.journal_title = openurl.referent.jtitle
          end
        end          
        item.issn           = node_text record.at_xpath("xerxes_record/standard_numbers/issn")    
        
        # authors
        record.xpath("xerxes_record/authors/author").each do |author|
          next unless author.at_xpath("aulast") # don't even have a lastname, we can do nothing
          
          item.authors << Author.new(:first => node_text(author.at_xpath("aufirst")),
            :middle => node_text(author.at_xpath("auinit")),
            :last => node_text(author.at_xpath("aulast"))
            )
        end
        
        
      end
      return results     
    end
    
    protected
    
    def xerxes_search_url(args)
      configuration.base_url.chomp("/") + "/?base=metasearch&action=search" +
        "&context=#{configuration.lookup!('xerxes_context', 'bento_search')}" +
        "&field=WRD" +
        "&query=#{CGI.escape(args[:query])}" + 
        configuration.databases.collect {|d| "&database=#{d}"}.join("&")
    end
    
    # returns nil if passed in nil, otherwise
    # returns nokogiri text()
    def node_text(node)
      return nil if node.nil?
      
      return node.text()
    end
    
  end  
end
