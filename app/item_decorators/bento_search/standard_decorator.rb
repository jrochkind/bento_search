module BentoSearch
  class StandardDecorator < DecoratorBase
    
    
    # How to display a BentoSearch::Author object as a name
    def author_display(author)
      if (author.first && author.last)
        "#{author.last}, #{author.first.slice(0,1)}"
      elsif author.display
        author.display
      elsif author.last
        author.last
      else
        nil
      end
    end
    
    # Put together title and subtitle if neccesary. 
    def complete_title
      t = self.title
      if self.subtitle
        t = safe_join([t, ": ", self.subtitle], "")        
      end
      
      if t.blank?
        t = I18n.translate("bento_search.missing_title")
      end
      
      return t
    end
    
    
    
    
    
    # A simple user-displayable citation, _without_ author/title.
    # the journal, year, vol, iss, page; or publisher and year; etc. 
    # Constructed from individual details. Not formal APA or MLA or anything,
    # just a rough and ready display. 
    #
    # TODO: Should this be moved to a rails helper method? Not sure. 
    def published_in
      result_elements = []
      
      result_elements.push("<span class='source_label'>#{I18n.t("bento_search.published_in")}</span><span class='source_title'>#{_h.html_escape source_title}</span>".html_safe) unless source_title.blank?      
      
      if source_title.blank? && ! publisher.blank?
        result_elements.push html_escape publisher
      end
      
      result_elements.push("#{I18n.t('bento_search.volume')} #{volume}") if volume.present?
      
      result_elements.push("#{I18n.t('bento_search.issue')} #{issue}") if issue.present?
            
      if (! start_page.blank?) && (! end_page.blank?)
        result_elements.push _h.html_escape "pp. #{start_page}-#{end_page}"
      elsif ! start_page.blank?
        result_elements.push _h.html_escape "p. #{start_page}"
      end
      
      return nil if result_elements.empty?
      
      return result_elements.join(", ").html_safe
    end
    
        # A display method, this is like #langauge_str, but will be nil if
    # the language_code matches the current default locale, used
    # for printing language only when not "English" normally. 
    #
    #(Sorry, will be 'Spanish' never 'Espa~nol", we don't
    # have a data source for language names in other languages right now. )
    def display_language
      return nil unless self.language_code
      
      default = I18n.locale.try {|l| l.to_s.gsub(/\-.*$/, '')} || "en" 
      
      this_doc = self.language_obj.try(:iso_639_1)
      
      return nil if this_doc == default
      
      self.language_str
    end
    
    # format string to display to user. Uses #format_str if present,
    # otherwise finds an i18n label from #format. Returns nil if none
    # available. 
    def display_format      
      value = self.format_str || 
        I18n.t(self.format, :scope => [:bento_search, :format], :default => self.format.to_s.titleize)
        
      return value.blank? ? nil : value        
    end

    
    ###################
    # turn into a representative OpenURL
    #
    #  use to_openurl_kev to go straight there, 
    #  or to_openurl to get a ruby OpenURL object.
    ###################
    

    # Returns a ruby OpenURL::ContextObject (NISO Z39.88).  
    # or nil if none avail. 
    def to_openurl
      return nil if openurl_disabled
      
      BentoSearch::OpenurlCreator.new(self).to_openurl
    end
    
    # Returns a kev encoded openurl, that is a URL query string representing
    # openurl. Or nil if none available. 
    #
    # Right now just calls #to_openurl.kev, can conceivably
    # be modified to do things more efficient, without a ruby openurl
    # obj. Law of demeter, represent.     
    def to_openurl_kev
      to_openurl.try(:kev)      
    end
    
  end
end
