## 1.8.0

* beforeSend param to ajax, see #30
* Workaround backwards-incompat changes in language_list 1.2.0 (https://github.com/scsmith/language_list/issues/19)

## 1.7

* search engines now have a `configuration.default_per_page`

* partials used by `bento_search` helper can be configured in BentoSearch.defaults,
  or at the engine config level as well. Now including `ajax_loading_partial`.

* `auto_rescued_exceptions` is now a Rails `class_attribute`, so can be configured
   more easily on a per-class _or_ per-instance basis with `SearchEngineClass.auto_rescue_exceptions = `
   or `engine.auto_rescue_exceptions = `.  Old way of over-riding `auto_rescue_exceptions`
   (note `rescue` vs `rescued`) is deprecated.

* auto_rescue includes SocketError

* EdsEngine improvements
  * EdsEngine gets much more structured citation data. EDS API has gotten better
    since it was written, it's now updated to take advantage of more.
    * `assume_first_custom_link_openurl` now defaults to **false**, as it should
       no longer be neccesary to get a good OpenURL out of EDS. But set to true
       if you want old behavior.
  * EdsEngine gets custom_data[:holdings] for catalog-type results.
  * EdsEngine notices weird `<Item><Group>URL</Group>` links in response,
    and 'parses' them to add as item#other_links
  * EdsEngine marks `link_is_fulltext=true` if api marks `plink` as
    "pdflink".

* New BentoSearch::ConcurrentSearcher for threaded concurrent searching.
  * With proper Rails 5 API usage to work with dev-mode class reloading,
    without deadlocks (but still works in any supported pre-5 Rails as well).
  * Based on [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby),
    now a dependency in Rails 5. To use in Rails previous to 5, just add
    `gem 'concurrent-ruby', '~> 1.0'` to your `Gemfile`.
  * Replaces the celluloid-based BentoSearch::MultiSearcher, which is now
    deprecated, but won't go away until bento_search 2.0.
    * The ConcurrentSearcher API is pretty similar to MultiSearcher, you can
      probably use it as a drop-in replacement.
    * If you continue to use MultiSearcher in Rails 5, you may need to
      turn off dev-mode class reloading (set `config.eager_load == true`
      and `config.cache_classes = true` in development) to avoid deadlocks from the Rails5
      autoload lock.
    * If you stop using MultiSearcher, you can remove `celluloid` from your Gemfile,
      unless you need it for some other reason.
    * If you previously turned off Rails dev-mode class reloading, it should
      work again in Rails5 with the ConcurrentSearcher.

* The JQuery ajax loader now allows you to set a default success callback
  applying to all loads:

      BentoSearch.ajax_load.default_success_callback = function(div) { ...

  More documentation of JQuery success callback on the [wiki](https://github.com/jrochkind/bento_search/wiki/AJAX-results-loading)

* BentoSearch::SearchEngine has `engine_id` and `display_configuration` cover
  methods added, for consistency with BentoSearch::Results

* standard engine `log_failed_results` config, if true all failed results
  are logged to `Rails.logger.error`. Can set global defaults with
  `BentoSearch.defaults.log_failed_results = true`


## 1.6

* Test under Rails5
* Test under MRI 2.3


## 1.5

* multi-field searching
* DOAJArticlesEngine new search engine
* New standard semantic fields including :source_title, :volume, :issue, :start_page

### 1.4.4

* Google Books Engine: Catch buggy invalid ID http response in #get

### 1.4.3

* Fix Scopus to properly handle zero-hit results, respond to undoc'd Scopus API change.

## 1.4.0

* Round-trippable JSON serialization of internal state of results
* Improvements to JournalTocsForJournal engine.

## 1.3.0

* Verified working with ruby 2.2.1 and Rails 4.2, with tests.
* Updated to Confstruct 1.x for configuration objects
