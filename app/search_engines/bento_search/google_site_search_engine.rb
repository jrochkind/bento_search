require 'cgi'
require 'multi_json'

require 'http_client_patch/include_client'
require 'httpclient'

# Under construction. TODO: Disable OpenURL (use a disabled_openurl attribute in item?)
#                           rename journal_title to source_title with alias. 
#             * sample_megasearch show no sort/field if none avail. 
#             * add standard sorting. https://developers.google.com/custom-search/docs/structured_data#page_dates
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
# * per-page is max 10, which makes it not too too useful. If you ask for more, you'll get an exception.
# * Google only lets you look at first 10 pages. If you ask for more, it won't raise,
#   it'll just give you the last page google will let you have. pagintion object
#   in result set will be appropriate for page you actually got though. 
# * 'abstract' field always filled out with relevant snippets from google api.  
# * Google API actually returns 'meta' information (from HTML meta tags and microdata?)
#   but we're not currently using it. 
# * The URL in display form is put in ResultItem#journal_title (ie source_title).
#   That should result in it rendering in a reasonable place with standard display
#   templates. 
# * no alternate sorts supported at present. Google api actually supports sort
#   by custom embedded metadata, but we don't support at present.  
# * no search fields supported at present. may possibly add later after more
#   investigation, google api may support both standard intitle etc, as well
#   as custom attributes added in microdata to your pages. 
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
    
    url = construct_query(args)
    
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
  
  # yep, google gives us a 10 max per page. 
  # also only lets us look at first 10 pages, sorry. 
  def max_per_page
    10
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
  
  # create the URL to the google API based on normalized search args
  #
  # If you ask for pagination beyond what google will provide, it
  # will give you the last page google will allow AND mutate the
  # args hash passed in to match what you actually got!
  def construct_query(args)
    url = "#{configuration.base_url}key=#{CGI.escape configuration.api_key}&cx=#{CGI.escape configuration.cx}"
    url += "&q=#{CGI.escape args[:query]}"
    
    
    url += "&num=#{args[:per_page]}" if args[:per_page]
    
    # google 'start' is 1-based. Google won't let you paginate
    # past ~10 pages (101 - num). We silently max out there without
    # raising. 
    if start = args[:start]
      num   = args[:per_page] || 10
      start = start + 1
      
      if start > (101 - num)
        # illegal! fix. 
        start         = (101 - num)
        args[:start]  = (start - 1) # ours is zero based
        args[:page]   = (args[:start] / num) + 1
      end
        
          
      url += "&start=#{start}"
    end
    
    return url
  end
  
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
