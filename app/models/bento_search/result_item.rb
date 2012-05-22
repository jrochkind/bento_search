module BentoSearch
  # Data object representing a single hit from a search, normalized
  # with common data fields. Usually held in a BentoSearch::Results object.
  #
  # ANY field can be nil, clients should be aware.  
  class ResultItem
    # * dc.title 
    # * schema.org CreativeWork: 'name'    
    attr_accessor :title
    
    # When an individual seperate subtitle is available. 
    # May also be nil with subtitle in "title" field after colon. 
    # 
    # * 
    attr_accessor :subtitle
    
    # usually a direct link to the search provider's 'native' page. 
    # Can be changed in actual presentation with a Decorator.
    # * schema.org CreativeWork: 'url'
    attr_accessor :link
    
    # schema.org 'type' that's a sub-type of CreativeWork. 
    # should hold a string that, when appended to "http://schema.org/"
    # is a valid schema.org type uri, that sub-types CreativeWork. 
    # 
    # OR one of these symbols, sadly not covered by schema.org types:
    # * :serial (magazine or journal)
    # * :dissertation (dissertation or thesis)
    attr_accessor :format
    
    # year published. a ruby int
    # PART of:. 
    # * schema.org CreativeWork "datePublished"
    # * dcterms.issued
    # * prism:?
    attr_accessor :year
    
    attr_accessor :volume
    attr_accessor :issue
    attr_accessor :start_page
    attr_accessor :end_page
    
    attr_accessor :journal_title
    attr_accessor :issn
    
    # an openurl kev-encoded context object. optional,
    # only if source provides one that may be better
    # than can be constructed from individual elements above
    attr_accessor :openurl_kev_co
    
    # Short summary of item. 
    # Mark .html_safe if it includes html -- creator is responsible
    # for making sure html is safely sanitizied and/or stripped,
    # rails ActionView::Helpers::Sanistize #sanitize and #strip_tags
    # may be helpful. 
    attr_accessor :abstract
  end
end
