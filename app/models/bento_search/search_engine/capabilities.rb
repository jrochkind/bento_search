
# Methods that describe a search engine's capabilities,
# mixed into SearchEngine. Individual engine implementations
# will often over-ride some or all of these methods. 
module BentoSearch::SearchEngine::Capabilities
      # If support fielded search, over-ride to specify fields
      # supported. Returns a hash, key is engine-specific internal
      # search field, value is nil or a hash of metadata about
      # the search field, including semantic mapping. 
      #
      # def search_field_definitions
      #  { "intitle" => {:semantic => :title}}
      # end
      def search_field_definitions
        {}
      end
      
      # Over-ride with a HASH of available sorts. Each key is the string
      # that will be passed in engine.search(...., :sort => key)
      # The key combines a choice of sort field, ascending/descending,
      # secondary sorts etc -- we combine this all with one key, because
      # typical examined interfaces did same from a select menu. 
      #
      # Keys should where possible be _standard_ keys chosen from
      # those listed in config/i18n/en:bento_search.sort_keys.*
      # But if you need something not there, it can be custom to engine.
      # Value of hash is for internal use by engine, it may be a convenient
      # place to store implementation details. 
      #
      # For a particular engine, a sort not mentioned here will-- raise?
      # be ignored? Not sure. 
      def sort_definitions
        {}
      end
      
      # Default per-page, returns 10 by default,
      # over-ride if different than 10
      def default_per_page
        10
      end
      
      # Override to return int max per-page. 
      def max_per_page
        nil
      end
      
      # Returns list of string internal search_field's that can
      # be supplied to search(:search_field => x)
      def search_keys        
        return search_field_definitions.keys
      end
      
      # Returns list of symbol semantic_search_field that can be
      # supplied to search(:semantic_search_field => x)
      def semantic_search_keys  
        semantic_search_map.keys
      end
      
      # returns a hash keyed by semantic search field symbol,
      # value string internal search field key. 
      def semantic_search_map                
        # Hash[] conveniently takes an array of k-v pairs. 
        return Hash[
          search_field_definitions.collect do |field, defn|
            [ defn[:semantic].to_s, field ] if defn && defn[:semantic]
          end.compact        
        ]
      end
      

end
