require 'nokogiri'

require 'http_client_patch/include_client'
require 'httpclient'

# Attempt to search using the WorldCat Search SRU variant, asking API for
# results in DC format. We'll see how far this takes us. 
#
# Does require an API key, and requires OCLC membership/FirstSearch subscription
# for access. 
#
# == API Docs
# * http://oclc.org/developer/documentation/worldcat-search-api/using-api
# * http://oclc.org/developer/documentation/worldcat-search-api/sru
# * http://oclc.org/developer/documentation/worldcat-search-api/parameters
class BentoSearch::WorldcatSruDcEngine
  include BentoSearch::SearchEngine
  
  extend HTTPClientPatch::IncludeClient
  include_http_client
  
  def search_implementation(args)
    url = construct_query_url(args)

    results = BentoSearch::Results.new
    
    response = http_client.get(url)
    
    if response.status != 200
      response.error ||= {}
      response.error[:status] = response.status
      response.error[:info] = response.body
      response.error[:url] = url
    end
    
    xml = Nokogiri::XML(response.body)
    # namespaces only get in the way
    xml.remove_namespaces!
    
    results.total_items = xml.at_xpath("//numberOfRecords").try {|n| n.text.to_i }
    
    
    (xml.xpath("/searchRetrieveResponse/records/record") || []).each do |record|
      item = BentoSearch::ResultItem.new
      
      item.title        = first_text_if_present record, "./recordData/oclcdcs/title"
      
      results << item
    end
    
    return results
  end
  
  def construct_query_url(args)
    url = configuration.base_url
    url += "&wskey=#{CGI.escape configuration.api_key}"
    url += "&recordSchema=#{CGI.escape 'info:srw/schema/1/dc'}"
    
    url += "&query=#{CGI.escape construct_cql_query(args)}"
  end
  
  def first_text_if_present(node, xpath)
    node.at_xpath(xpath).try {|n| n.text}
  end
  
  # construct valid CQL for the API's "query" param, from search
  # args. Tricky because we need to split terms/phrases ourselves
  #
  # returns CQL that is NOT uri escaped yet. 
  def construct_cql_query(args)
    field = "srw.kw" # later be field specific from args please. 
    
    # We need to split terms and phrases, so we can formulate
    # CQL with seperate clauses for each, bah. 
    tokens = args[:query].split(%r{\s|("[^"]+")}).delete_if {|a| a.blank?}
    

    
    return tokens.collect do |token|
      quoted_token = nil
      if token =~ /^".*"$/
        # phrase
        quoted_token = token
      else
        # escape internal double quotes with single backslash. sorry ruby escaping
        # makes this crazy. 
        token = token.gsub('"', %Q{\\"})
        quoted_token = %Q{"#{token}"}
      end
      
      "#{field} = #{quoted_token}"
      end.join(" AND ")    
  end

  def self.required_configuration
    [:api_key]
  end
  
  def self.default_configuration
    {
      :base_url => "http://www.worldcat.org/webservices/catalog/search/sru?"
    }
  end
  
end
