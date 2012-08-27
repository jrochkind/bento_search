# An item decorator that just erases all links, main link and other
# links. 
module BentoSearch::NoLinks
  
  def link
    nil
  end
  
  def other_links
    []
  end

end
