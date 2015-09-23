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