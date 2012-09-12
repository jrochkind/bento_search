# Some utiltiy methods exposed as global module methods. 
module BentoSearch::Util
  extend ActionView::Helpers::OutputSafetyHelper # for safe_join

  
  
  # Used for when API's give you a string with embedded snippet
  # highlighting tags. can replace those with our own
  # standard tags, mark html_safe appropriately, etc. 
  #
  # will always return an html_safe buffer, as it includes
  # our output <b> tags. 
  #
  # must pass in options:
  # [:highlight_start]  start tag in source for highlighting
  # [:highlight_end]    end tag in source for highlighting.
  #
  # May pass in options:
  #
  # [:strip]    default false, if true strip source highlighting
  #             tags without replacing with our own.
  #
  # [:html_safe_source] default false. If true, assume source is already
  #                     html safe and does not need to be escaped. 
  #
  # [:enabled]  default true, if pass in false this method will
  #             just return input str doing nothing to it. Can be
  #             useful to embed this logic for calling code. 
  def self.handle_highlight_tags(str, options = {})
    unless options.has_key?(:start_tag) && options.has_key?(:end_tag) 
      raise ArgumentError.new("Need :start_tag and :end_tag")
    end
            
    options.reverse_merge!(
      :output_start_tag => '<b class="bento_search_highlight">',
      :output_end_tag => '</b>',
      :enabled => true
      )
        
    
    
    # Need to do nothing for empty string
    return str if str.blank? || (! options[:enabled])
    
    if options[:strip]
      # Just strip em, don't need to replace em with HTML
      str = str.gsub(Regexp.new(Regexp.escape options[:start_tag]), '')
      str = str.gsub(Regexp.new(Regexp.escape options[:end_tag]), '')
      return str
    end
    
    parts = 
      str.
      split( %r{(#{Regexp.escape options[:start_tag]}|#{Regexp.escape options[:end_tag]})}  ).
        collect do |substr|
          case substr
            when  options[:start_tag] then options[:output_start_tag].html_safe
            when  options[:end_tag] then options[:output_end_tag].html_safe
            else  options[:html_safe_source] ? substr.html_safe : substr
          end
        end
        
    return safe_join(parts, '')
  end
  
  # Turn a string into a constant/class object, lexical lookup
  # within BentoSearch module. Can use whatever would be legal
  # in ruby, "A", "A::B", "::A::B" (force top-level lookup), etc. 
  def self.constantize(klass_string)        
    unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ klass_string
      raise NameError, "#{klass_string.inspect} is not a valid constant name!"
    end

    BentoSearch.module_eval(klass_string, __FILE__, __LINE__)
  end
  
  
    
    
end
