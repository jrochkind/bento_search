module BentoSearch
  #TODO: NEEDS AUTH FOR PROTECTED ENGINES!!! configuration.auth => symbol
  #of controller/helper method avail in ApplicationController
  class SearchController < BentoSearchController    
    
    # returns partial HTML results, suitable for
    # AJAX to insert into DOM. 
    def search      
      engine = BentoSearch.get_engine(params[:engine_id])

      @results = engine.search(params.to_hash.symbolize_keys)
      
      render :layout => false      
    end
    
  end
end
