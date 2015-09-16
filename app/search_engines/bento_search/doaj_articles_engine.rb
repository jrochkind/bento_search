require 'httpclient'
require 'http_client_patch/include_client'

require 'json'

module BentoSearch
  class DoajArticlesEngine
    include BentoSearch::SearchEngine
    include ActionView::Helpers::SanitizeHelper


    class_attribute :http_timeout
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

      response = http_client.get( query_url )

      json = JSON.parse(response.body)

      results.total_items = json["total"]

      (json["results"] || []).each do |item_response|
        results <<  hash_to_item(item_response)
      end

      return results
    end


    def args_to_search_url(arguments)
      query = if arguments[:search_field]
        fielded_query(arguments[:query], arguments[:search_field])
      else
        escape_query(arguments[:query])
      end

      url = self.base_url + CGI.escape(query)

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

    def fielded_query(field, query)
      "field:#{escape_query query}"
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
    # This method does NOT return URI-escaped, it returns literal, escaped for ES. 
    def escape_query(q)
      q.gsub(/([\+\-\=\&\|\>\<\!\(\)\{\}\[\]\^\"\~\*\?\:\\\/])/) {|m| "\\#{$1}"}
    end


    ###########
    # BentoBox::SearchEngine API
    ###########

    def max_per_page
      100
    end

    def search_field_definitions
      # DOAJ supports 'exact match' searches, we're going to add
      # them in with :semantic with _exact on the end, not strictly
      # supported by current bento_search api?
      { nil                     => {:semantic => :general},
        "bibjson.title"         => {:semantic => :title},
        "bibjson.author.name"   => {:semantic => :author},
        "publisher"             => {:semantic => :publisher},
        "bibjson.subject"       => {:semantic => :subject},
        "bibjson.journal.title" => {:semantic => :publication_title},
        "issn"                  => {:semantic => :issn},
        "doi"                   => {:semantic => :doi},
        "bibjson.journal.volume.exact"   => {:semantic => :volume},
        "bibjson.journal.number.exact"   => {:semantic => :issue},
        "bibjson.start_page"   => {:semantic => :start_page},
        "license" => {}
      }
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