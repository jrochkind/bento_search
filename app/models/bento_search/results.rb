module BentoSearch
  # An array-like object (in fact it-subclasses Array) that holds
  # a page of search results. But also has some meta-data about the
  # search itself (query, paging, etc). 
  
  # If #error is non-nil, object  may not have real results, but
  # be an error. You can use failed? to see. 
  class Results < ::Array
    attr_accessor :total_items
    # 0-based index into total results, used for pagination
    attr_accessor :start
    # per_page setting, can be used for pagination. 
    attr_accessor :per_page

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
    
    # time it took to do search, in seconds. 
    attr_accessor :timing
    
    # search arguments as normalized by SearchEngine, not neccesarily
    # directly as input. A hash. 
    attr_accessor :search_args
    # Registered id of engine used to create these results, 
    # may be nil if used with an unregistered engine.
    attr_accessor :engine_id
    
    def failed?
      ! error.nil?
    end
  end
end
