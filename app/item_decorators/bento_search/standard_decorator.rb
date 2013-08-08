module BentoSearch
  class StandardDecorator < DecoratorBase


    # convenience method that returns true if any of the keys
    # are #present?  eg
    # item.any_present?(:source_title, :authors) === item.source_title.present? || item.authors.present?
    #
    # note present? is false for nil, empty strings, and empty arrays.
    def any_present?(*keys)
      keys.each do |key|
        return true if self.send(key).present?
      end
      return false
    end

    # How to display a BentoSearch::Author object as a name
    def author_display(author)
      if (author.first.present? && author.last.present?)
        "#{author.last}, #{author.first.slice(0,1)}"
      elsif author.display.present?
        author.display
      elsif author.last.present?
        author.last
      else
        nil
      end
    end

    # display multiple authors, with HTML markup, returns html_safe string.
    # experimentally trying this as a decorator helper method rather
    # than a view partial, not sure which is best.
    #
    # Will limit to first three authors, with elipsis if there are more.
    #
    # Over-ride if you want to format authors names differently, or
    # show more or less than first 3, etc.
    def render_authors_list
      parts = []

      first_three = self.authors.slice(0,3)

      first_three.each_with_index do |author, index|
        parts << _h.content_tag("span", :class => "author") do
          self.author_display(author)
        end
        if (index + 1) < first_three.length
          parts << "; "
        end
      end

      if self.authors.length > 3
        parts << I18n.t("bento_search.authors_et_al")
      end

      return _h.safe_join(parts, "")
    end

    # Returns source publication name OR publisher, along with volume/issue/pages
    # if present, all wrapped in various tags and labels. Returns html_safe
    # with tags.
    #
    # Experiment to do this in a decorator helper instead of a partial template,
    # might be more convenient we think.
    def render_source_info
      parts = []

      if self.source_title.present?
        parts << _h.content_tag("span", I18n.t("bento_search.published_in"), :class=> "source_label")
        parts << _h.content_tag("span", self.source_title, :class => "source_title")
        parts << ". "
      elsif self.publisher.present?
        parts << _h.content_tag("span", self.publisher, :class => "publisher")
        parts << ". "
      end

      if text = self.render_citation_details
        parts << text << "."
      end

      return _h.safe_join(parts, "")
    end

    # if enough info is present that there will be non-empty render_source_info
    # should be over-ridden to match display_source_info
    def has_source_info?
      self.any_present?(:source_title, :publisher, :start_page)
    end

    # Mix-in a default missing title marker for empty titles
    # (Used to combine title and subtitle when those were different fields)
    def complete_title
      if self.title.present?
        self.title
      else
        I18n.translate("bento_search.missing_title")
      end
    end



    # volume, issue, and page numbers. With prefixed labels from I18n.
    # That's it.
    def render_citation_details
      # \u00A0 is unicode non-breaking space to keep labels and values from
      # getting separated.
      result_elements = []

      result_elements.push("#{I18n.t('bento_search.volume')}\u00A0#{volume}") if volume.present?

      result_elements.push("#{I18n.t('bento_search.issue')}\u00A0#{issue}") if issue.present?

      if (! start_page.blank?) && (! end_page.blank?)
        result_elements.push html_escape "#{I18n.t('bento_search.pages')}\u00A0#{start_page}-#{end_page}"
      elsif ! start_page.blank?
        result_elements.push html_escape "#{I18n.t('bento_search.page')}\u00A0#{start_page}"
      end

      return nil if result_elements.empty?

      return result_elements.join(", ").html_safe
    end

    # A summary. If config.for_dispaly.prefer_snippets_as_summary is set to true
    # then prefers that, otherwise abstract.
    #
    # Truncates for display.
    def render_summary
      summary = nil
      max_chars = (self.display_configuration.try {|h| h["summary_max_chars"]}) || 280



      if self.snippets.length > 0 && !(self.display_configuration.try {|h| h["prefer_abstract_as_summary"]} && self.abstract)
        summary = self.snippets.first
        self.snippets.slice(1, self.snippets.length).each do |snippet|
          summary += ' '.html_safe + snippet if (summary.length + snippet.length) <= max_chars
        end
      else
        summary = _h.bento_truncate( self.abstract, :length => max_chars )
      end

      summary
    end

    # A display method, this is like #langauge_str, but will be nil if
    # the language_code matches the current default locale, used
    # for printing language only when not "English" normally.
    #
    #(Sorry, will be 'Spanish' never 'Espa~nol", we don't
    # have a data source for language names in other languages right now. )
    def display_language
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

    # outputs a date for display, from #publication_date or #year.
    # Uses it's own logic to decide whether to output entire date or just
    # year, if it has a complete date. (If volume and issue are present,
    # just year).
    #
    # Over-ride in a decorator if you want to always or never or different
    # logic for complete date. Or if you want to change the format of the date,
    # etc.
    def display_date
      if self.publication_date
        if self.volume && self.issue
          # just the year, ma'am
          I18n.localize(self.publication_date, :format => "%Y")
        else
          # whole date, since we got it
          I18n.localize(self.publication_date, :format => "%d %b %Y")
        end
      elsif self.year
        self.year.to_s
      else
        nil
      end
    end

    # A unique opaque identifier for a record may sometimes be
    # required, for instance in Atom.
    #
    # We here provide a really dumb implementation, if and only if
    # the result has an engine_id and unique_id available, (and
    # a #root_url is available) by basically concatenating them to
    # app base url.
    #
    # That's pretty lame, probably not resolvable, but best we
    # can do without knowing details of host app. You may want
    # to over-ride this in a decorator to do something more valid
    # in an app-specific way.
    #
    # yes uri_identifier is like PIN number, deal with it.
    def uri_identifier
      if self.engine_id.present? && self.unique_id.present? && _h.respond_to?(:root_url)
        "#{_h.root_url.chomp("/")}/bento_search_opaque_id/#{CGI.escape self.engine_id}/#{CGI.escape self.unique_id}"
      else
        nil
      end
    end

    # Can be used as an id attribute for anchor destination in HTML.
    # Will return "#{prefix}_#{index}" -- if prefix is missing,
    # will use #engine_id if present. If both are missing, returns nil.
    # if index missing, returns nil.
    def html_id(prefix, index)
      prefix = prefix || self.engine_id
      prefix, index = prefix.to_s, index.to_s

      return nil if index.empty?
      return nil if prefix.empty?

      return "#{prefix}_#{index}"
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
