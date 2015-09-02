require 'bento_search'

# Holds a list of registered search engines with configuration. 
# There's one global one referened by BentoSearch module, but one
# might want to create multiple. 
class BentoSearch::Registrar
  class ::BentoSearch::NoSuchEngine < ::BentoSearch::Error ; end
  
  def initialize    
    @registered_engine_confs = {}
  end
  
  # Register a configuration for a BentoSearch search engine. 
  # While some parts of BentoSearch can be used without globally registering
  # a configuration, it is neccesary for features like AJAX load, and
  # convenient in other places. 
  #
  # BentoSearch.register_engine("gbs") do |conf|
  #    conf.engine = "GoogleBooksSearch"
  #    conf.api_key = "my_key"
  # end
  #
  # BentoSearch.get_engine("gbs")
  #    => a BentoSearch::GoogleBooksSearch, configured as specified. 
  #
  # The first parameter identifier, eg "gbs", may be used in some
  # URLs, for AJAX etc. 
  #
  # You can also pass in a hash or hash-like object (including
  # a configuration object returned by a prior register_engine)
  # instead of or in addition to the block 'dsl' -- this can be used
  # to base one configuration off another, with changes:
  #
  #     BentoSearch.register_engine("original", {
  #       :engine => "Something",
  #       :title => "Original",
  #       :shared => "shared"
  #     })
  #
  #     BentoSearch.register_engine("derived") do |conf|
  #        conf.title = "Derived"
  #     end
  #
  # Above would not change 'shared' in 'original', but would
  # over-ride 'title' in 'derived', without changing 'title' in
  # 'original'. 
  def register_engine(id, conf_data = nil, &block)
    conf = Confstruct::Configuration.new
    
    # Make sure we make a deep_copy so any changes don't mutate
    # the original. Confstruct can be unpredictable. 
    if conf_data.present?
      conf_data = Confstruct::Configuration.new(conf_data).deep_copy
    end
    
    conf.configure(conf_data, &block)
    conf.id = id.to_s
    
    raise ArgumentError.new("Must supply an `engine` class name") unless conf.engine
    
    @registered_engine_confs[id] = conf    
    
    return conf
  end
  
  # Get a configured SearchEngine, using configuration and engine
  # class previously registered for `id` with #register_engine. 
  # Raises a BentoSearch::NoSuchEngine if is is not registered.
  def get_engine(id)
    conf = @registered_engine_confs[id.to_s]
    
    raise BentoSearch::NoSuchEngine.new("No registered engine for identifier '#{id}'") unless conf
    
    # Figure out which SearchEngine class to instantiate
    klass = constantize(conf.engine)
    
    return klass.new( conf )
  end
  
  # Mostly just used for testing
  def reset_engine_registrations!
    @@registered_engine_confs = {}
  end
  
  protected
  
  # Turn a string into a constant/class object, lexical lookup
  # within BentoSearch module. Can use whatever would be legal
  # in ruby, "A", "A::B", "::A::B" (force top-level lookup), etc. 
  def constantize(klass_string)     
    BentoSearch::Util.constantize(klass_string)    
  end
  

  
end
