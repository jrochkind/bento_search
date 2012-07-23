# Example of an Item Decorator that ADDs an 'other link' with an openurl. 
#
# This example uses crazy metaprogramming to dynamically create
# a module configured with your base url etc. You don't need to use
# crazy method like that; just define your own local decorator doing
# exactly what you need, it's meant to be simple. 
#
#  config.item_decorators = [ BentoSearch::OpenurlAddOtherLink[:base_url => "http://resolve.somewhere.edu/foo", :extra_query => "&foo=bar"] ]
#
module BentoSearch::OpenurlAddOtherLink
  def self.[](options)
    base_url = options[:base_url]
    extra_query = options[:extra_query] || ""
    link_name = options[:link_name] || "Find It"
    Module.new do
      
      define_method :other_links do
        if (ou = to_openurl)
          super() + [BentoSearch::Link.new(:url => "#{base_url}?#{ou.kev}#{extra_query}", :label => link_name)]
        else
          super()
        end        
      end
      
    end
  end
  
  
  
end
