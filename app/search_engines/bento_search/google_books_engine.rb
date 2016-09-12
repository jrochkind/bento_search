require 'httpclient'
require 'cgi'
require 'multi_json'

# not sure why we need to require the entire 'helpers'
# when all we want is sanitize_helper, but I think we do:
require 'action_view/helpers'
#require 'action_view/helpers/sanitize_helper'

require 'http_client_patch/include_client'

module BentoSearch
  #
  # https://developers.google.com/books/docs/v1/using
  # https://developers.google.com/books/docs/v1/reference/volumes#resource
  #
  # Configuration :api_key STRONGLY recommended, or google will severely
  # rate-limit you.
  #
  # == Custom Data
  # GBS API's "viewability" value is stored at item.custom_data[:viewability]
  # PARTIAL, ALL_PAGES, NO_PAGES or UNKNOWN.
  # https://developers.google.com/books/docs/v1/reference/volumes#resource
  #
  # #link_is_fulltext? is also set appropriately.
  #
  # You may want to use a custom decorator to display the viewability
  # status somehow (in display_format? In an other_link?). See wiki
  # for info on decorators.
  class GoogleBooksEngine
    include BentoSearch::SearchEngine
    include ActionView::Helpers::SanitizeHelper

    extend HTTPClientPatch::IncludeClient
    include_http_client # gives us a #http_client with persistent class-level

    class_attribute :base_url
    self.base_url = "https://www.googleapis.com/books/v1/"


    def search_implementation(arguments)
      query_url = args_to_search_url(arguments)

      results = Results.new

      begin
        response = http_client.get(query_url )
        json = MultiJson.load( response.body )
        # Can't rescue everything, or we catch VCR errors, making
        # things confusing.
      rescue BentoSearch::RubyTimeoutClass, HTTPClient::TimeoutError,
            HTTPClient::ConfigurationError, HTTPClient::BadResponseError  => e
        results.error ||= {}
        results.error[:exception] = e
      end

      # Trap json parse error, but also check for bad http
      # status, or error reported in the json. In any of those cases
      # return results obj with error status.
      #
      if ( response.nil? || json.nil? ||
          (! HTTP::Status.successful? response.status) ||
          (json && json["error"]))

       results.error ||= {}
       results.error[:status] = response.status if response
       if json && json["error"] && json["error"]["errors"] && json["error"]["errors"].kind_of?(Array)
         results.error[:message] = json["error"]["errors"].first.values.join(", ")
       end
       results.error[:error_info] = json["error"] if json && json.respond_to?("[]")

       # escape early!
       return results
      end


      results.total_items = json["totalItems"]

      (json["items"] || []).each do |item_response|
        results <<  hash_to_item(item_response)
      end

      return results
    end

    # Look up a single item by #unique_id. Returns a single item, or
    # raises BentoSearch::NotFound, BentoSearch::TooManyFound, or other.
    def get(id)
      # Have to use different API endpoint, can't do a fielded search.
      url = base_url + "volumes/#{CGI.escape id}"

      if configuration.api_key
        url += "?key=#{configuration.api_key}"
      end

      response = http_client.get( url )

      if response.status == 404
        raise BentoSearch::NotFound.new("ID: #{id}")
      end

      # GBS has switched to returning a 503 for bad id's???
      # Prob a bug on Google's end, but we have to deal with it.
      if response.status == 503
        raise BentoSearch::NotFound.new("ID: #{id} (503 error from Google, tests show indicates not found ID however)")
      end

      json = MultiJson.load( response.body )

      if json["error"]
        raise Exception.new("Error in get(#{id}): #{json['error'].inspect}")
      end

      return hash_to_item(json)
    end

    # take a hash from Google json response, representing a single
    # item, return a ResultItem obj. Used internally.
    def hash_to_item(item_response)
      v_info = item_response["volumeInfo"] || {}

      item = ResultItem.new

      item.unique_id             = item_response["id"]

      item.title          = format_title(v_info)
      item.publisher      = v_info["publisher"]
      # previewLink gives you your search results highlighted, preferable
      # if it exists.
      item.link           = v_info["previewLink"] || v_info["canonicalVolumeLink"]
      item.abstract       = sanitize v_info["description"]
      item.year           = get_year v_info["publishedDate"]
      # sometimes we have yyyy-mm, but we need a date to make a ruby Date,
      # we'll just say the 1st.
      item.publication_date = case v_info["publishedDate"]
        when /(\d\d\d\d)-(\d\d)/ then Date.parse "#{$1}-#{$2}-01"
        when /(\d\d\d\d)-(\d\d)-(\d\d)/ then Date.parse v_info["published_date"]
        else nil
      end


      item.format         = if v_info["printType"] == "MAGAZINE"
                            :serial
                          else
                            "Book"
                          end



      item.language_code  = v_info["language"]

      (v_info["authors"] || []).each do |author_name|
        item.authors << Author.new(:display => author_name)
      end

      # Find ISBN's, prefer ISBN-13
      item.isbn           = (v_info["industryIdentifiers"] || []).find {|node| node["type"] == "ISBN_13"}.try {|node| node["identifier"]}
      unless item.isbn
        # Look for ISBN-10 okay
        item.isbn         = (v_info["industryIdentifiers"] || []).find {|node| node["type"] == "ISBN_10"}.try {|node| node["identifier"]}
      end


      # only VERY occasionally does a GBS hit have an OCLC number, but let's look
      # just in case.
      item.oclcnum        = (v_info["industryIdentifiers"] || []).
        find {|node| node["type"] == "OTHER" && node["identifier"].starts_with?("OCLC:") }.
        try do |node|
          node =~ /OCLC:(.*)/ ? $1 : nil
        end

      # save viewability status in custom_data. PARTIAL, ALL_PAGES, NO_PAGES or UNKNOWN.
      # https://developers.google.com/books/docs/v1/reference/volumes#resource
      item.custom_data[:viewability] = item_response["accessInfo"].try {|h| h["viewability"]}
      item.link_is_fulltext = (item.custom_data[:viewability] == "ALL_PAGES") if item.custom_data[:viewability]

      return item
    end




    ###########
    # BentoBox::SearchEngine API
    ###########

    def max_per_page
      100
    end

    def search_field_definitions
      { nil           => {:semantic => :general},
        "intitle"     => {:semantic => :title},
        "inauthor"    => {:semantic => :author},
        "inpublisher" => {:semantic => :publisher},
        "subject"     => {:semantic => :subject},
        "isbn"        => {:semantic => :isbn}
      }
    end

    def sort_definitions
      {
        "relevance" => {:implementation => nil}, # default
        "date_desc" => {:implementation => "newest"}
      }
    end

    def multi_field_search?
      true
    end

    protected


    #############
    # Our own implementation code
    ##############


    # takes a normalized #search arguments hash from SearchEngine
    # turns it into a URL for Google API. Factored out to make testing
    # possible.
    def args_to_search_url(arguments)
      query = if arguments[:query].kind_of? Hash
        #multi-field
        arguments[:query].collect {|field, query_value| fielded_query(query_value, field)}.join(" ")
      elsif arguments[:search_field]
        fielded_query(arguments[:query], arguments[:search_field])
      else
        arguments[:query]
      end

      query_url = base_url + "volumes?q=#{CGI.escape  query}"
      if configuration.api_key
        query_url += "&key=#{configuration.api_key}"
      end

      if arguments[:per_page]
        query_url += "&maxResults=#{arguments[:per_page]}"
      end
      if arguments[:start]
        query_url += "&startIndex=#{arguments[:start]}"
      end

      if arguments[:sort] &&
          (defn = sort_definitions[arguments[:sort]]) &&
          (value = defn[:implementation])
        query_url += "&orderBy=#{CGI.escape(value)}"
      end


      return query_url
    end


    # If they ask for a <one two> :intitle, we're
    # actually gonna do like google's own form does,
    # and change it to <intitle:one intitle:two>. Internal
    # phrases will be respected.
    def fielded_query(query, field)
      tokens = query.split(%r{\s|("[^"]+")}).delete_if {|a| a.blank?}
      return tokens.collect {|token| "#{field}:#{token}"}.join(" ")
    end


    def get_year(iso8601)
      return nil if iso8601.blank?

      if iso8601 =~ /^(\d{4})/
        return $1.to_i
      end
      return nil
    end

    def format_title(v_info)
      title = v_info["title"]
      if v_info["subtitle"]
        title = "#{title}: #{v_info["subtitle"]}"
      end
      return title
    end

  end
end
