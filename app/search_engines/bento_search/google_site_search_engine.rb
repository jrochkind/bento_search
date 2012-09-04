require 'cgi'
require 'multi_json'

require 'http_client_patch/include_client'
require 'httpclient'

# Under construction. TODO: Disable OpenURL (use a disabled_openurl attribute in item?)
#                           rename journal_title to source_title with alias. 
#
# An adapter for Google Site Search/Google Custom Search 
#
# I think those are the same thing now, but may get differnet names
# depending on whether you are paying for getting for free. The free
# version only gives you 100 requests/day courtesy limit for testing. 
#
# Create a custom/site search: http://www.google.com/cse
# API docs: https://developers.google.com/custom-search/v1/overview
# API console to get API key? https://code.google.com/apis/console/?pli=1#project:183362013039
#
# == Limitations
#
# * per-page is max 10, which makes it not too too useful. 
# * And it seems you're only allowed to look at first 10 pages, so
# max of 10 for page or 91 for start.
# * 'abstract' field always filled out with relevant snippets from google api.  
# * Google API actually returns 'meta' information (from HTML meta tags and microdata?)
#   but we're not currently using it. 
# * The URL in display form is put in ResultItem#journal_title (ie source_title).
#   That should result in it rendering in a reasonable place with standard display
#   templates. 
# * no alternate sorts supported
# * no search fields supported at present (may possibly add later)
#
# == Required config params
# [:api_key]  api_key from google, get from Google API Console
# [:cx]       identifier for specific google CSE, get from "Search engine unique ID" in CSE "Control Panel"
#
# == Optional config params
#
# [:highlighting]  default false. if true, then title, display url, and snippets will
#                  have HTML <b> tags in them, and be html_safe. If false, plain
#                  ascii, but you'll still get snippets. 
class BentoSearch::GoogleSiteSearchEngine
  include BentoSearch::SearchEngine
  
  extend HTTPClientPatch::IncludeClient
  include_http_client
    
  def search_implementation(args)
    results = BentoSearch::Results.new
    
    url = "#{configuration.base_url}key=#{CGI.escape configuration.api_key}&cx=#{CGI.escape configuration.cx}"
    url += "&q=#{CGI.escape args[:query]}"
    
    response = http_client.get(url)
    
    if response.status != 200
      results.error ||= {}
      results.error[:status] = response.status
      results.error[:response] = response.body
      return results
    end
    
    json = MultiJson.load(response.body)
    
    results.total_items =  json["searchInformation"]["totalResults"].to_i
    
    json["items"].each do |json_item|
      item = BentoSearch::ResultItem.new
      
      if configuration.highlighting
        item.title          = highlight_normalize json_item["htmlTitle"]
        item.abstract       = highlight_normalize json_item["htmlSnippet"]
        item.journal_title  = highlight_normalize json_item["htmlFormattedUrl"]
      else
        item.title          = json_item["title"]
        item.abstract       = json_item["snippet"]
        item.journal_title  = json_item["formattedUrl"]
      end
      
      item.link             = json_item["link"]
      
      results << item
    end
    
    return results
  end
  
  
  def self.required_configuation
    [:api_key, :cx]
  end
  
  def self.default_configuration
    { 
      :base_url => 'https://www.googleapis.com/customsearch/v1?',
      :highlighting => true    
    }
  end
  
  protected
  
  # normalization for strings returned by google as 'html' with query
  # in context highlighting. 
  #
  # * change straight <b></b> tags given by google for highlighting
  # to <b class="bento_search_highight">. 
  # * remove <br> tags that google annoyingly puts in; we'll handle
  #   line wrapping ourselves thanks. 
  # * and mark html_safe
  def highlight_normalize(str)
    str.gsub("<b>", '<b class="bento_search_highlight">').
      gsub("<br>", "").
      html_safe
  end
  
end
