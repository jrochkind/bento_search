# EXAMPLE of an Item Decorator that replaces the main 'link'
# with an openurl.
#
# This example uses crazy metaprogramming to dynamically create
# a module configured with your base url etc. You don't need to use
# crazy method like that; just define your own local decorator doing
# exactly what you need, it's meant to be simple.
#
#  config.item_decorators = [ BentoSearch::OpenurlMainLink[:base_url => "http://resolve.somewhere.edu/foo", :extra_query => "&foo=bar"] ]
#
module BentoSearch::OpenurlMainLink
  def self.[](options)
    base_url = options[:base_url]
    extra_query = options[:extra_query] || ""
    Module.new do

      define_method :link do
        if (ou = to_openurl)
          "#{base_url}?#{ou.kev}#{extra_query}"
        else
          nil
        end
      end

    end
  end



end
