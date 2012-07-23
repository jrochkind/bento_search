require "bento_search/engine"
require 'bento_search/routes'
require 'confstruct'

# ugh, sorry:
require File.dirname(__FILE__) + '/../app/models/bento_search/registrar'

module BentoSearch  
  
  def self.global_registrar
    @@global_registrar ||= BentoSearch::Registrar.new
  end
       
  def self.register_engine(id, &block)
    global_registrar.register_engine(id, &block)    
  end
  
  def self.get_engine(id)
    global_registrar.get_engine(id)
  end
      
  # Mostly just used for testing
  def self.reset_engine_registrations!
    global_registrar.reset_engine_registrations!
  end

end


