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
      # (or we can add it there?). 
      # Value of hash is for internal use by engine, it may be a convenient
      # place to store implementation details. 
      #
      # For a particular engine, a sort not mentioned here will-- raise?
      # be ignored? Not sure. 
      def sort_definitions
        {}
      end
      
      # convenience to get just the sort keys, which is what client
      # cares about. 
      def sort_keys
        sort_definitions.keys
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


      # Engines that support multi-field search should
      # override to return true. Returns false in base
      # default implementation. 
      #
      # If an engine returns true here, it can receive in :query
      # a Hash of multiple fields/values. The fields will all be
      # normalized to internal names before engine receives them. 
      # The multi-field search is meant to be run as a boolean AND
      # of all field/values. 
      def multi_field_search?
        return false
      end
      

end
