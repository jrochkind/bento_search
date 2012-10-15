# encoding: UTF-8

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
  
  # An HTML-safe truncation using nokogiri, based off of:
  # http://blog.madebydna.com/all/code/2010/06/04/ruby-helper-to-cleanly-truncate-html.html
  #
  # but without monkey-patching, and behavior more consistent with Rails
  # truncate. 
  #
  # It's hard to get all the edge-cases right, we probably mis-calculate slightly
  # on edge cases, and we aren't always able to strictly respect :separator, sometimes
  # breaking on tag boundaries instead. But this should be good enough for actual use
  # cases, where those types of incorrect results are still good enough. 
  #
  # ruby 1.9 only, in 1.8.7 non-ascii won't be handled quite right. 
  #
  # Pass in a Nokogiri node, probably created with Nokogiri::HTML::DocumentFragment.parse(string)
  #
  # Might want to check length of your string to see if, even with HTML tags, it's
  # still under limit, before parsing as nokogiri and passing in here -- for efficiency.
  #
  # Get back a Nokogiri node, call #inner_html on it to go back to a string 
  # (and you probably want to call .html_safe on the string you get back for use
  # in rails view)
  #
  # (In future consider using this gem instead of doing it ourselves? https://github.com/nono/HTML-Truncator )
  def self.nokogiri_truncate(node, max_length, omission = '…', separator = nil)
        
    if node.kind_of?(::Nokogiri::XML::Text)   
      if node.content.length > max_length
        allowable_endpoint = [0, max_length - omission.length].max
        if separator
          allowable_endpoint = (node.content.rindex(separator, allowable_endpoint) || allowable_endpoint)
        end        
        
        ::Nokogiri::XML::Text.new(node.content.slice(0, allowable_endpoint) + omission, node.parent)
      else
        node.dup
      end
    else # DocumentFragment or Element
      return node if node.inner_text.length <= max_length
      
      truncated_node = node.dup
      truncated_node.children.remove
      remaining_length = max_length 
      
      node.children.each do |child|
        #require 'debugger'
        #debugger
        if remaining_length == 0
          truncated_node.add_child ::Nokogiri::XML::Text.new(omission, truncated_node)
          break
        elsif remaining_length < 0          
          break        
        end
        truncated_node.add_child nokogiri_truncate(child, remaining_length, omission, separator)
        # can end up less than 0 if the child was truncated to fit, that's
        # fine: 
        remaining_length = remaining_length - child.inner_text.length

      end
      truncated_node
    end
    
  end
    
end
