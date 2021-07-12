# EXAMPLE of an Item Decorator that ADDs an 'other link' with an openurl.
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
    # overwrite: if true, overwrite previously existing other_links, if
    # false add on to previously existing.
    overwrite = options.has_key?(:overwrite) ? options[:overwrite] : false

    Module.new do

      define_method :other_links do
        start = overwrite ? [] : super()
        if (ou = to_openurl)
          start + [BentoSearch::Link.new(:url => "#{base_url}?#{ou.kev}#{extra_query}", :label => link_name)]
        else
          start
        end
      end

    end
  end



end
