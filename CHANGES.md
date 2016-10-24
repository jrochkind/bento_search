## 1.7
* auto_rescue includes SocketError

* search engines now have a `configuration.default_per_page`

* partials used by `bento_search` helper can be configured in BentoSearch.defaults,
  or at the engine config level as well. Now including `ajax_loading_partial`.

* `auto_rescued_exceptions` is now a Rails `class_attribute`, so can be configured
   more easily on a per-class _or_ per-instance basis with `SearchEngineClass.auto_rescue_exceptions = `
   or `engine.auto_rescue_exceptions = `.  Old way of over-riding `auto_rescue_exceptions`
   (note `rescue` vs `rescued`) is deprecated.

* EdsEngine gets much more structured citation data. EDS API has gotten better
  since it was written, it's now updated to take advantage of more.
  * `assume_first_custom_link_openurl` now defaults to **false**, as it should
     no longer be neccesary to get a good OpenURL out of EDS. But set to true
     if you want old behavior.

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
