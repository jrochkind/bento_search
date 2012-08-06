require 'openurl'

# A Decorator that will make #to_openurl refuse to construct
# an openurl from individual elements, it'll use the #openurl_kev_co
# or nothing. 
module BentoSearch::OnlyPremadeOpenurl
  
  def to_openurl
    if self.openurl_kev_co
      return OpenURL::ContextObject.new_from_kev( self.openurl_kev_co )
    else
      return nil
    end
  end
  
end
