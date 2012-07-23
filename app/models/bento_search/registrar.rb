
# Holds a list of registered search engines with configuration. 
# There's one global one referened by BentoSearch module, but one
# might want to create multiple. 
class BentoSearch::Registrar
  class ::BentoSearch::NoSuchEngine < Exception ; end
  
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
  def register_engine(id, &block)
    conf = Confstruct::Configuration.new(&block)
    conf.id = id.to_s
    
    raise ArgumentError.new("Must supply an `engine` class name") unless conf.engine
    
    @registered_engine_confs[id] = conf    
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
    unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ klass_string
      raise NameError, "#{klass_string.inspect} is not a valid constant name!"
    end

    BentoSearch.module_eval(klass_string, __FILE__, __LINE__)
  end
  

  
end
