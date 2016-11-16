require 'httpclient'
require 'http_client_patch/include_client'

require 'json'

module BentoSearch
  # DOAJ Articles search.
  # https://doaj.org/api/v1/docs
  #
  # Phrase searches with double quotes are respected.
  #
  # Supports #get by unique_id feature
  #
  class DoajArticlesEngine
    include BentoSearch::SearchEngine
    include ActionView::Helpers::SanitizeHelper


    class_attribute :http_timeout, instance_writer: false
    self.http_timeout = 10

    extend HTTPClientPatch::IncludeClient
    include_http_client do |client|
      client.connect_timeout = client.send_timeout = client.receive_timeout = self.http_timeout
    end

    class_attribute :base_url
    self.base_url = "https://doaj.org/api/v1/search/articles/"

    def search_implementation(arguments)
      query_url = args_to_search_url(arguments)

      results = Results.new

      begin
        Rails.logger.debug("DoajEngine: requesting #{query_url}")
        response = http_client.get( query_url )
        json = JSON.parse(response.body)
      rescue BentoSearch::RubyTimeoutClass, HTTPClient::TimeoutError,
             HTTPClient::ConfigurationError, HTTPClient::BadResponseError,
             JSON::ParserError  => e
        results.error ||= {}
        results.error[:exception] = e
      end

      if ( response.nil? || json.nil? ||
          (! HTTP::Status.successful? response.status) ||
          (json && json["error"]))

        results.error ||= {}
        results.error[:status] = response.status if response
        results.error[:message] = json["error"] if json["error"]

        return results
      end

      results.total_items = json["total"]

      (json["results"] || []).each do |item_response|
        results <<  hash_to_item(item_response)
      end

      return results
    end

    def get(unique_id)
      results = search(unique_id, :search_field => "id")

      raise (results.error[:exception] || StandardError.new(results.error[:message] || results.error[:status])) if results.failed?
      raise BentoSearch::NotFound.new("For id: #{unique_id}") if results.length == 0
      raise BentoSearch::TooManyFound.new("For id: #{unique_id}") if results.length > 1

      results.first
    end


    def args_to_search_url(arguments)
      query = if arguments[:query].kind_of?(Hash)
        # multi-field query
        arguments[:query].collect {|field, query_value| fielded_query(query_value, field)}.join(" ")
      else
        fielded_query(arguments[:query], arguments[:search_field])
      end

      # We need to escape this for going in a PATH component,
      # not a query. So space can't be "+", it needs to be "%20",
      # and indeed DOAJ API does not like "+".
      #
      # But neither CGI.escape nor URI.escape does quite
      # the right kind of escaping, seems to work out
      # if we do CGI.escape but then replace '+'
      # with '%20'
      escaped_query = CGI.escape(query).gsub('+', '%20')
      url = self.base_url + escaped_query

      query_args = {}

      if arguments[:per_page]
        query_args["pageSize"]  = arguments[:per_page]
      end

      if arguments[:page]
        query_args["page"]      = arguments[:page]
      end

      if arguments[:sort] &&
          (defn = sort_definitions[arguments[:sort]]) &&
          (value = defn[:implementation])
        query_args["sort"] = value
      end

      query = query_args.to_query
      url = url + "?" + query if query.present?

      return url
    end

    # Prepares a DOAJ API (elastic search) query component for
    # given textual query in a given field (or default non-fielded search)
    #
    # Separates query string into tokens (bare words and phrases),
    # so they can each be made mandatory for ElasticSearch. Default
    # DOAJ API makes them all optional, with a very low mm, which
    # leads to low-precision odd looking results for standard use
    # cases.
    #
    # Escapes all remaining special characters as literals (not including
    # double quotes which can be used for phrases, which are respected. )
    #
    # Eg:
    #     fielded_query('apple orange "strawberry banana"', field_name)
    #     # => '+field_name(+apple +orange +"strawberry banana")'
    #
    # The "+" prefixed before field-name is to make sure all separate
    # fields are also mandatory when doing multi-field searches. It should
    # make no difference for a single-field search.
    def fielded_query(query, field = nil)
      if field.present?
        "+#{field}:(#{prepare_mandatory_terms(query)})"
      else
        prepare_mandatory_terms(query)
      end
    end

    # Takes a query string, prepares an ElasticSearch query
    # doing what we want:
    #   * tokenizes into bare words and double-quoted phrases
    #   * Escapes other punctuation to be literal not ElasticSearch operator.
    #     (Does NOT do URI escaping)
    #   * Makes each token mandatory with an ElasticSearch "+" operator prefixed.
    def prepare_mandatory_terms(query)
      # use string split with regex to too-cleverly split into space
      # seperated terms and phrases, keeping phrases as unit.
      terms = query.split %r{[[:space:]]+|("[^"]+")}
      # Wound up with some empty strings, get rid of em
      terms.delete_if {|t| t.blank?}

      terms.collect {|token| "+" + escape_query(token)}.join(" ")
    end

    # Converts from item found in DOAJ results to BentoSearch::ResultItem
    def hash_to_item(hash)
      item = ResultItem.new

      bibjson = hash["bibjson"] || {}

      item.unique_id  = hash["id"]

      # Hard-code to Article, we don't get any format information
      item.format     = "Article"

      item.title      = bibjson["title"]


      item.start_page = bibjson["start_page"]
      item.end_page   = bibjson["end_page"]

      item.year       = bibjson["year"]
      if (year = bibjson["year"].to_i) && (month = bibjson["month"].to_i)
        if year != 0 && month != 0
          item.publication_date = Date.new(bibjson["year"].to_i, bibjson["month"].to_i)
        end
      end

      item.abstract   = sanitize(bibjson["abstract"]) if bibjson.has_key?("abstract")

      journal           = bibjson["journal"] || {}
      item.volume       = journal["volume"]
      item.issue        = journal["number"]
      item.source_title = journal["title"]
      item.publisher    = journal["publisher"]
      item.language_str = journal["language"].try(:first)

      (bibjson["identifier"] || []).each do |id_hash|
        case id_hash["type"]
        when "doi"
          item.doi = id_hash["id"]
        when "pissn"
          item.issn = id_hash["id"]
        end
      end

      (bibjson["author"] || []).each do |author_hash|
        if author_hash.has_key?("name")
          author = Author.new(:display => author_hash["name"])
          item.authors << author
        end
      end

      # I _think_ DOAJ articles results always only have one link,
      # and it may always be of type 'fulltext'
      link_hash             = (bibjson["link"] || []).first
      if link_hash && link_hash["url"]
        item.link             = link_hash["url"]
        item.link_is_fulltext = true if link_hash["type"] == "fulltext"
      end

      return item
    end

    # Escape special chars in query, Doaj says it's elastic search,
    # punctuation that needs to be escaped and how to escape (backslash)
    # for ES documented here: https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html
    #
    # We do not escape double quotes, want to allow them for phrases.
    #
    # This method does NOT return URI-escaped, it returns literal, escaped for ES.
    def escape_query(q)
      q.gsub(/([\+\-\=\&\|\>\<\!\(\)\{\}\[\]\^\~\*\?\:\\\/])/) {|m| "\\#{$1}"}
    end


    ###########
    # BentoBox::SearchEngine API
    ###########

    def max_per_page
      100
    end

    def search_field_definitions
      { nil                     => {:semantic => :general},
        "bibjson.title"         => {:semantic => :title},
        # Using 'exact' seems to produce much better results for
        # author, don't entirely understand what's up.
        "bibjson.author.name"   => {:semantic => :author},
        "publisher"             => {:semantic => :publisher},
        "bibjson.subject.term"  => {:semantic => :subject},
        "bibjson.journal.title" => {:semantic => :source_title},
        "issn"                  => {:semantic => :issn},
        "doi"                   => {:semantic => :doi},
        "bibjson.journal.volume"   => {:semantic => :volume},
        "bibjson.journal.number"   => {:semantic => :issue},
        "bibjson.start_page"   => {:semantic => :start_page},
        "license" => {},
        "id"      => {}
      }
    end

    def multi_field_search?
      true
    end

    def sort_definitions
      # Don't believe DOAJ supports sorting by author
      {
        "relevance" => {:implementation => nil}, # default
        "title" => {:implementation => "title:asc"},
        # We don't quite have publication date sorting, but we'll use
        # created_date from DOAJ
        "date_desc" => {:implementation => "article.created_date:desc"},
        "date_asc"  => {:implementation => "article.created_date:asc"},
        # custom one not previously standardized
        "publication_name" => {:implementation => "bibjson.journal.title:asc"}
      }
    end

  end
end
