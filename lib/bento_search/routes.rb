# -*- encoding : utf-8 -*-
module BentoSearch
  class Routes

    def initialize(router, options = {})
      @router = router
      @options = {:scope => "/bento"}.merge(options)
    end

    def draw
      route_sets.each do |r|
        self.send(r)
      end
    end

    protected

    def add_routes &blk
      @router.instance_exec(@options, &blk)
    end

    def route_sets
      (@options[:only] || default_route_sets) - (@options[:except] || [])
    end

    def default_route_sets
      # :search should always be LAST
      [:search]
    end

    module RouteSets
      
      def search
        add_routes do |options|
          scope options[:scope] do
            get ":engine_id" => "bento_search/search#search", :as => "to_bento_search"
          end
        end
        
      end
        
    end
    include RouteSets
  end
end
