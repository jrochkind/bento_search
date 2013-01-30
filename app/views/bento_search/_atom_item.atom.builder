# single BentoSearch::ResultItem as an atom:entry.
# Assumes atom is default namespace, and uses standard prefixes
# for other namespaces, prism and dc

# Pass in local 'builder' with xml object from parent builder template,
# for best results with indenting etc. 
#
# render :partial => "bento_search/atom_item", :collection => results, :locals => {:builder => xml } 
builder ||= xml  # or use the rails-provided 'xml' builder. 

item = atom_item # rails passes in as atom_item, name of partial. 

builder.entry do 
  builder.title item.complete_title
    
  # updated is required, for now we'll just set it to now, sorry
  builder.updated Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
  
  # links? Let's include all, main and alternate. If 'rel' and
  # possibly 'type' attributes are present on other_links, they'll
  # be used. Main link is assumed rel 'self'
  if item.link                        
    builder.link  "rel" => "alternate", "href" => item.link
  end
  item.other_links.each do |link|
    args = {}
    args["rel"]   = link.rel   if link.rel.present?
    args["type"]  = link.type  if link.type.present?
    args["title"] = link.label if link.label.present?
    args["href"]  = link.url
    
    builder.link args
  end
    
  item.authors.each do |author|
    builder.author item.author_display(author)
  end
    
  if item.abstract.present? 
    builder.summary "type" => (item.abstract.html_safe? ? "html" : "text") do
      builder.text! item.abstract
    end
  end      
end
