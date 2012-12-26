# An item decorator mix-in that just erases all links, main link and other
# links. May be convenient to `include BentoSearch::NoLinks` in your 
# custom decorator, although you could always just write this yourself too. 
module BentoSearch::NoLinks
  
  def link
    nil
  end
  
  def other_links
    []
  end

end
