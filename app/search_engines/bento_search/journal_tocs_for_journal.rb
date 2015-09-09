require 'nokogiri'
require 'httpclient'
require 'httpclient/include_client'

require 'htmlentities'

module BentoSearch

  # Powered by JournalTocs (http://www.journaltocs.hw.ac.uk/index.php?action=api)
  # This is NOT actually a typical Bento Search engine, it does not let you
  # search for keywords, there is actually no #search method.
  #
  # Instead, you can pull up list of current articles for a journal
  # with #fetch_by_issn(issn)
  #
  # Theoretically, JournalTocs could support a very basic keyword search too,
  # but it's very limited, and I didn't have a use case for it, so didn't implement.
  # If someone wants it though, a normal bento search engine with very basic
  # functionality could be implemented.
  #
  # Required config:
  #
  #   [:registered_email]   email address you've registered with JournalTocs
  #               http://www.journaltocs.ac.uk/index.php?action=register
  class JournalTocsForJournal
    include BentoSearch::SearchEngine

    HttpTimeout = 3
    extend HTTPClient::IncludeClient
    include_http_client do |client|
      client.connect_timeout = client.send_timeout = client.receive_timeout = HttpTimeout
    end

    include ActionView::Helpers::SanitizeHelper # strip_tags






    # return a nokogiri document of journal Tocs results. Usually just for internal use, use
    # #fetch_by_issn instead.
    #
    # May raise JournalTocsFetcher::FetchError on error (bad baseURL, bad API key,
    # error response from journaltocs)
    def fetch_xml(issn)

      xml =
        begin
          url = request_url(issn)
          response = http_client.get(url)

          # In some cases, status 401 seems to be bad email
          unless response.ok?
            # trim some XML boilerplate and remove newlines
            # from response body, for better error message
            response_body = response.body.gsub(/[\n\t]/, '').sub(/\A<\?xml[^>]*\>/, '')

            raise FetchError.new("#{url}: returns #{response.status} response: #{response_body}")
          end

          Nokogiri::XML(response.body)
        rescue SocketError => e
          raise FetchError.new("#{url}: #{e.inspect}")
        end

      # There's no good way to tell we got an error from unregistered email
      # or other usage problem except sniffing the XML to try and notice
      # it's giving us a usage message.
      if ( xml.xpath("./rdf:RDF/rss:item", xml_ns).length == 1 &&
           xml.at_xpath("./rdf:RDF/rss:item/rss:link", xml_ns).try(:text) == "http://www.journaltocs.ac.uk/develop.php" )
        raise FetchError.new("Usage error on api call, missing registered email? #{request_url}")
      end

      return xml
    end

    # returns an array of BentoSearch::ResultItem objects, representing
    # items.
    def fetch_by_issn(issn)
      xml = fetch_xml(issn)


      results = BentoSearch::Results.new.concat(
        xml.xpath("./rdf:RDF/rss:item", xml_ns).collect do |node|
          item = BentoSearch::ResultItem.new

          item.format = "Article"

          item.issn   = issn # one we searched with, we know that!

          item.title  = xml_text(node, "rss:title")
          item.link   = xml_text(node, "rss:link")

          item.publisher      = xml_text(node, "prism:publisher") || xml_text(node, "dc:publisher")
          item.source_title   = xml_text(node, "prism:PublicationName")
          item.volume         = xml_text(node, "prism:volume")
          item.issue          = xml_text(node, "prism:number")
          item.start_page     = xml_text(node, "prism:startingPage")
          item.end_page       = xml_text(node, "prism:endingPage")

          # Look for something that looks like a DOI in dc:identifier
          node.xpath("dc:identifier").each do |id_node|
            if id_node.text =~ /\ADOI (.*)\Z/
              item.doi = $1
              # doi's seem to often have garbage after a "; ", especially
              # from highwire. heuristically fix, sorry, a real DOI with "; "
              # will get corrupted.
              if (parts = item.doi.split("; ")).length > 1
                item.doi = parts.first
              end

              break
            end
          end

          # authors?
          node.xpath("dc:creator", xml_ns).each do |creator_node|
            name = creator_node.text
            name.strip!

            # author names in RSS seem to often have HTML entities,
            # un-encode them to literals.
            name = HTMLEntities.new.decode(name)


            item.authors << BentoSearch::Author.new(:display => name)
          end

          # Date is weird and various formatted, we do our best to
          # look for yyyy-mm-dd at the beginning of either prism:coverDate or
          # dc:date or prism:publicationDate
          date_node = xml_text(node, "prism:coverDate") || xml_text(node, "dc:date") || xml_text(node, "prism:publicationDate")
          if date_node && date_node =~ /\A(\d\d\d\d-\d\d-\d\d)/
            item.publication_date = Date.strptime( $1, "%Y-%m-%d")
          elsif date_node
            # Let's try a random parse, they give us all kinds of things I'm afraid
            item.publication_date = Date.parse(date_node) rescue ArgumentError
          end

          # abstract, we need to strip possible HTML tags (sometimes they're
          # there, sometimes not), and also decode HTML entities. 
          item.abstract   = xml_text(node, "rss:description").try do |text|            
            HTMLEntities.new.decode(strip_tags(text))
          end

          item
        end
      )

      # Items seem to come back in arbitrary order, we want to sort
      # by date reverse if we can
      if results.all? {|i| i.publication_date.present? }
        results.sort_by! {|i| i.publication_date}.reverse!
      end

      fill_in_search_metadata_for(results)

      return results
    end

    # just a convenience method
    def xml_text(node, xpath)
      node.at_xpath(xpath, xml_ns).try(:text)
    end


    # xml namespaces used in JournalTocs response, for nokogiri xpaths
    def xml_ns
      { "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "rss" => "http://purl.org/rss/1.0/",
        "prism"=>"http://prismstandard.org/namespaces/1.2/basic/",
        "dc"=>"http://purl.org/dc/elements/1.1/",
        "mn"=>"http://usefulinc.com/rss/manifest/",
        "content"=>"http://purl.org/rss/1.0/modules/content/"
      }
    end

    def request_url(issn)
      "#{configuration.base_url}/journals/#{issn}?output=articles&user=#{CGI.escape configuration.registered_email}"
    end

    def self.default_configuration
      {
        :base_url => 'http://www.journaltocs.ac.uk/api'
      }
    end

    def self.required_configuration
      ["registered_email"]
    end

    class FetchError < BentoSearch::FetchError ; end


  end
end
