require 'cgi'
require 'nokogiri'

require 'http_client_patch/include_client'
require 'httpclient'
module BentoSearch
  # Supports fielded searching, sorting, pagination.
  #
  # Required configuration:
  # * api_key
  #
  # Defaults to 'relevance' sort, rather than scopus's default of date desc.
  #
  # Uses the Scopus SciVerse REST API. You need to be a Scopus customer
  # to access. http://api.elsevier.com
  # http://www.developers.elsevier.com/action/devprojects
  #
  # ToS: http://www.developers.elsevier.com/devcms/content-policies
  # "Federated Search" use case.
  # Also: http://www.developers.elsevier.com/cms/apiserviceagreement
  #
  # Note that ToS applying to you probably means you must restrict access
  # to search functionality to authenticated affiliated users only.
  #
  # Register for an API key at "Register New Site" at http://developers.elsevier.com/action/devnewsite
  # You will then need to get server IP addresses registered with Scopus too,
  # apparently by emailing directly to dave.santucci at elsevier dot com.
  #
  # Scopus API Docs:
  # * http://api.elsevier.com/documentation/SCOPUSSearchAPI.wadl
  # * http://api.elsevier.com/documentation/search/SCOPUSSearchViews.htm
  #
  # Query syntax and search fields:
  # * http://api.elsevier.com/documentation/search/SCOPUSSearchTips.htm
  #
  # Some more docs on response elements and query elements:
  # * http://api.elsevier.com/content/search/#d0n14606
  #
  # Other API's in the suite not being used by this code at present:
  # * http://www.developers.elsevier.com/devcms/content-api-retrieval-request
  # * http://www.developers.elsevier.com/devcms/content-api-metadata-request
  #
  # Support: Integration@scopus.com
  #
  # TODO: Mention to Scopus: Only one author?
  # Paging of 50 gets an error, but docs say I should be able to request 200. q
  #
  # Scopus response does not seem to include language of hit, even though
  # api allows you to restrict by language. ask scopus if we're missing something?
  class ScopusEngine
    include BentoSearch::SearchEngine

    extend HTTPClientPatch::IncludeClient
    include_http_client

    def search_implementation(args)
      results = Results.new

      xml, response, exception = nil, nil, nil

      url = scopus_url(args)

      begin
        response = http_client.get( url , nil,
          # HTTP headers.
          {"X-ELS-APIKey" => configuration.api_key,
          "X-ELS-ResourceVersion" => "XOCS",
          "Accept" => "application/atom+xml"}
        )

        xml = Nokogiri::XML(response.body)
      rescue BentoSearch::RubyTimeoutClass, HTTPClient::ConfigurationError, HTTPClient::BadResponseError, Nokogiri::SyntaxError  => e
        exception = e
      end

      # handle errors
      if (response.nil? || xml.nil? || exception ||
          (! HTTP::Status.successful? response.status) ||
          xml.at_xpath("service-error") ||
          xml.at_xpath("./atom:feed/atom:entry/atom:error", xml_ns)
          )

        # UGH. Scopus reports 0 hits as an error, not entirely distinguishable
        # from an actual error. Oh well, we have to go with it.
        if (
            (response.status == 400) &&
            xml &&
            (error_xml = xml.at_xpath("./service-error/status")) &&
            (node_text(error_xml.at_xpath("./statusCode")) == "INVALID_INPUT") &&
            (node_text(error_xml.at_xpath("./statusText")).starts_with? "Result set was empty")
          )
          # PROBABLY 0 hit count, although could be something else I'm afraid.
          results.total_items = 0
          return results
        elsif (
            (response.status == 200) &&
            xml &&
            (error_xml = xml.at_xpath("./atom:feed/atom:entry/atom:error", xml_ns)) &&
            (error_xml.text == "Result set was empty")
          )
          # NEW way of Scopus reporting an error that makes no sense either
          results.total_items = 0
          return results
        else
          # real error
          results.error ||= {}
          results.error[:exception] = e
          results.error[:status] = response.status if response
          results.error[:error_info] = xml.at_xpath("service-error").text.gsub!(/[\n\t ]+/, " ") if xml
          results.error[:error_info] ||= xml.at_xpath("./atom:feed/atom:entry/atom:error", xml_ns).text if xml
          return results
        end
      end


      results.total_items = (node_text xml.at_xpath("//opensearch:totalResults", xml_ns)).to_i

      xml.xpath("//atom:entry", xml_ns).each do | entry |

        results << (item = ResultItem.new)
        if scopus_link = entry.at_xpath("atom:link[@ref='scopus']", xml_ns)
          item.link = scopus_link["href"]
        end

        item.unique_id             = node_text entry.at_xpath("dc:identifier", xml_ns)

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

        # get the year out of the date
        if date = entry.at_xpath("prism:coverDate", xml_ns)
          date.text =~ /^(\d\d\d\d)/
          item.year = $1.to_i if $1
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
          item.format     = doctype_to_format(doctype.text)
          item.format_str = doctype_to_string(doctype.text)
        end

      end

      return results
    end

    # The escaping rules are not entirely clear for the API. We know colons
    # and parens are special chars. It's unclear how or if we can escape them,
    # we'll just remove them.
    def escape_query(query)
      # backslash escape doesn't seem to work
      #query.gsub(/([\\\(\)\:])/) do |match|
      #  "\\#{$1}"
      #end
      query.gsub(/([\\\(\)\:])/, ' ')
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

    # Max per-page is 200, as per http://www.developers.elsevier.com/devcms/content-apis, bottom of page.
    def max_per_page
      200
    end

    def search_field_definitions
      {
        nil           => {:semantic => :general},
        "AUTH"        => {:semantic => :author},
        "TITLE"       => {:semantic => :title},
        # controlled and author-assigned keywords
        "KEY"         => {:semantic => :subject},
        "ISBN"        => {:semantic => :isbn},
        "ISSN"        => {:semantic => :issn},
        "VOLUME"      => {:semantic => :volume},
        "ISSUE"       => {:semantic => :issue},
        "PAGEFIRST"   => {:semantic => :start_page},
        # Should we use SRCTITLE instead? I think exact match might be better?
        "EXACTSRCTITLE" => {:semantic => :source_title},
        "DOI"         => {:semantic => :doi},
        "PUBYEAR"     => {:semantic => :year}
      }
    end

    def sort_definitions
      # scopus &sort= values, not yet URI-escaped, later code will do that.
      #
      # 'refeid' key is currently undocumented on Scopus site, but
      # was given to me in email by scopus.
      {
        "title_asc"     => {:implementation => "+itemtitle"},
        "date_desc"     => {:implementation => "-datesort,+auth"},
        "relevance"     => {:implementation => "refeid" },
        "author_asc"    => {:implementation => "+auth"},
        "num_cite_desc" => {:implementation => "-numcitedby"}
      }
    end

    def multi_field_search?
      true
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
    def doctype_to_format(doctype)
      { "ar" => "Article",
        "bk" => "Book",
        "bz" => "Article",
        "re" => "Article", # most of what scopus labels 'Report' seem to be ordinary articles.
        "cp" => :conference_paper,
        "sh" => "Article", # 'short survey' to scopus, but seems to be used for articles.
        "ip" => "Article", # 'article in press'.
        'ed' => "Article", # Editorial
        'le' => "Article", # Letter
        'no' => "Article", # Note
      }[doctype.to_s]
    end

    # Maps Scopus doctype to human readable strings as documented by Scopus,
    # does not map 1-1 to our controlled format.
    def doctype_to_string(doctype)
      { "ar" => "Article",
        "ab" => "Abstract Report",
        "ip" => "Article in Press",
        "bk" => "Book",
        "bz" => "Business Article",
        "cp" => "Conference Paper",
        "cr" => "Conference Review",
        "ed" => "Editorial",
        "er" => "Erratum",
        "le" => "Letter",
        "no" => "Note",
        "pr" => "Press Release",
        "re" => "Article", # Really 'report', but Scopus is unreliable here, most of these are actually articles.
        "sh" => "Article" # Really 'short survey' to Scopus, but seems to be used for, well, articles.
      }[doctype.to_s]
    end




    def scopus_url(args)
      query = if args[:query].kind_of? Hash
        args[:query].collect {|field, query| fielded_query(query,field)}.join(" AND ")
      elsif args[:search_field]
        fielded_query(args[:query], args[:search_field])
      else
        escape_query args[:query]
      end

      query = "#{configuration.base_url.chomp("/")}/content/search/index:#{configuration.cluster}?query=#{CGI.escape(query)}"

      query += "&count=#{args[:per_page]}" if args[:per_page]

      query += "&start=#{args[:start]}" if args[:start]

      # default to 'relevance' sort if not given, rather than scopus's
      # default of date desc.
      args[:sort] ||= "relevance"
      if (defn = self.sort_definitions[args[:sort]]) &&
         ( value = defn[:implementation])
        query += "&sort=#{CGI.escape(value)}"
      end

      return query
    end

    def fielded_query(query, field)
      "#{field}(#{escape_query query})"
    end

  end
end
