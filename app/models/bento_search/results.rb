require 'json'

module BentoSearch
  # An array-like object (in fact it-subclasses Array) that holds
  # a page of search results. But also has some meta-data about the
  # search itself (query, paging, etc). 
  #
  # If #error is non-nil, object  may not have real results, but
  # be an error. You can use failed? to see. 
  #
  # Serializes as a Hash including ONLY the serialized results themselves,
  # and the engine ID.  Search context (total items, start, etc) are not
  # included in serialization. Configuration context is also not serialized,
  # although since the engineID is, it can be reconstructed on de-serialization. 
  #
  # Serialization isn't actually implemented with the BentoSearch::Results::Serialization
  # module, cause it didn't work out, just re-implemented here with same methods. 
  class Results < ::Array
    attr_accessor :total_items
    # 0-based index into total results, used for pagination
    attr_accessor :start
    # per_page setting, can be used for pagination. 
    attr_accessor :per_page
    
    # simply copied over from search engine configuration :display key,
    # useful for making config available at display time in a DRY way. 
    attr_accessor :display_configuration

    # If error is non-nil, it's an error condition with no real results.
    # error should be a hash with these (and possibly other) keys, although
    # none of these are required to be non-nil. 
    # [:status] 
    #     A (usually) non-succesful HTTP status code. May be nil. 
    # [:message]
    #     A short message explaining error, usually provided by external
    #     service. NOT suitable for showing to end-users. May be nil. 
    # [:end_user_message]
    #     A message suitable for showing to end-users. May be nil. 
    # [:error_info]
    #     A service-specific way of reporting more error info, for developers,
    #     not suitable for end-users. Might be a string, might be a hash,
    #     depends on the service. may be nil. 
    # [:exception]
    #     Possibly a ruby exception object. may be nil. 
    attr_accessor :error
    
    # time it took to do search, in seconds as float 
    attr_accessor :timing
    # timing from #timing, but in miliseconds as int
    def timing_ms
      return nil if timing.nil?
      (timing * 1000).to_i
    end
    
    # search arguments as normalized by SearchEngine, not neccesarily
    # directly as input. A hash. 
    attr_accessor :search_args
    # Registered id of engine used to create these results, 
    # may be nil if used with an unregistered engine.
    attr_accessor :engine_id

    
    # Returns a BentoSearch::Results::Pagination, that should be suitable
    # for passing right to Kaminari (although Kaminari isn't good about doc/specing
    # it's api, so might break), or convenient methods for your own custom UI. 
    def pagination
      Pagination.new( total_items, search_args)
    end
    
    def failed?
      ! error.nil?
    end
    
    def inspect
      "<BentoSearch::Results #{super} #{'FAILED' if self.failed?}>"
    end

    # Serialization
    def internal_state_hash
      {
        "engine_id" => self.engine_id,
        "result_items" => self.collect {|i| i.internal_state_hash},
        "bento_search_version" => BentoSearch::VERSION
      }
    end

    # Creates a Results object from an internal_state_hash, and restores
    # it's configuration from engine_id
    def self.from_internal_state_hash(hash)
      results = BentoSearch::Results.new
      results.engine_id = hash["engine_id"]
      hash["result_items"].each do |item_hash|
        results << BentoSearch::ResultItem.from_internal_state_hash(item_hash)
      end

      if results.engine_id
        BentoSearch.get_engine(results.engine_id).fill_in_search_metadata_for(results, {})
      end

      return results
    end

    def dump_to_json
      JSON.dump self.internal_state_hash
    end

    def self.load_json(json_str)
      from_internal_state_hash JSON.parse(json_str)
    end


    
  end
end
