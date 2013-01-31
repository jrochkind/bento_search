
#    Render a BentoSearch::Results as an Atom response -- since it is enhanced with
#    prism metadata about articles, and opensearch metadata about the search,
#    this can serve as a general API response for bento_search results. 
#    
#    Pass in some locals with feed metadata, author and title are required
#    by atom. eg.  
#    render "atom", :object => results, :locals => {:title => "Name of my app", :author => "some author"}, :format => :atom
#    
#    But both author and title will default to "search results".
#
# For more info on PRISM, see http://purl.org/rss/1.0/modules/prism/ among other
# places. We don't use that namespace since we're atom, not rss. 
# or an example of PRISM in Atom from Nature, who generally knows what they're
# doing, at: http://www.nature.com/opensearch/request?query=doi=%2210.1038/4611053b%22&httpAccept=application/atom%2Bxml

feed_title  = local_assigns[:feed_name] || "Search Results"
feed_author = local_assigns[:feed_author_name] || "Search Results"

# our object is passed in with name of template, more convenient as 'results' 
# If nil passed in, use empty result object to avoid raising and
# render a fairly empty response
results     = atom_results || BentoSearch::Results.new


xml.instruct!(:xml, :encoding => "UTF-8")

xml.feed("xmlns"            => "http://www.w3.org/2005/Atom",
         "xmlns:opensearch" => "http://a9.com/-/spec/opensearch/1.1/",
         "xmlns:prism"      => "http://prismstandard.org/namespaces/basic/2.1/",
         "xmlns:dcterms"    => "http://purl.org/dc/terms/",
         "xmlns:bibo"       => "http://purl.org/ontology/bibo/" ) do

  # "id" element required, we try to set it to the current app url
  xml.id request.url

  xml.title   feed_title
  xml.author  do
    xml.name feed_author
  end
  
  # TODO: Figure out a way to include self, alternate/html, and next/prev
  # links in a generic way?
  
  xml.opensearch :totalResults, results.pagination.count_records
  # Unclear if opensearch startIndex is 0-based or 1-based, appears
  # to be vendor-specific? So we'll use our 0-based. 
  # https://bugzilla.mozilla.org/show_bug.cgi?id=308674
  # Which ironically means we need to substract one from the pagination
  xml.opensearch :startIndex,   (results.pagination.start_record - 1)
  xml.opensearch :itemsPerPage, results.pagination.per_page
  
  # todo: include an opensearch query role?
  #xml.opensearch :Query, :role => "request", :searchTerms => params[:q], :startPage => page_info.current_page
  
  # updated is required, for now we'll just set it to now, sorry
  xml.updated Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")

  render :partial => "bento_search/atom_item", :collection => results, :locals => {:builder => xml}
  
end
