# Rails helper module provided by BentoSearch meant to be included
# in host app's helpers. 
module BentoSearchHelper
  
  def bento_search(search, options = {})
    results = search if search.kind_of? BentoSearch::Results
    
    engine = nil
    unless results
      # need to load an engine and do a search, or ajax, etc. 
      engine = if search.kind_of? BentoSearch::SearchEngine
        search
      else
        BentoSearch.get_engine(search.to_s)
      end      
      
    end
    
    if (!results && options[:load] == :ajax)
      content_tag(:div, :class => "bento_search_ajax_wait",
        :"data-bento-ajax-url" => "foo") do
        content_tag("noscript") do
          "Can not load results without javascript"
        end
      end
    else
      results = engine.search(options) unless results
      render :partial => "bento_search/std_item", :collection => results    
    end                          
  end
    
    
  
end
