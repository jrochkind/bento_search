# BentoSearch

(**in progress*, not yet ready for use, mainly because we need more
out of the box search engines supported). 

bento_search provides an abstraction/normalization layer for querying and 
displaying results for external search engines, in Ruby on Rails. Requires
Rails3 and tested only under ruby 1.9.3. 

* It is focused on use cases for academic libraries, but may be useful in generic
cases too. Initially, engine adapters are planned to be provided for: 
Google Books, Scopus, SerialSolutions Summon, Ex Libris Primo, 
and EBSCO Discovery Service. (Possibly ThomsonReuters Web of Knowledge). Most
of these search engines require a vendor license to use. 

* bento_search could be considered building blocks for a type of 'federated
search' functionality, but it does not and will never support merging results
from multiple engines into one result set. It is meant to support displaying the
first few results from multiple engines on one page, "bento box" style (as
named by Tito Sierra@NCSU), as well as more expanded single-search-on-a-page
uses. 

* bento_search provides abstract functionality for pagination, sorting, 
and single-field-specified queries. Faceting, limiting, and 'advanced'
multi-field searches are not yet supported, but planned. Not all
search engine adapters support all features.  Search engine adapters can
declare search fields and sort options with 'semantics', so you can for
instance search or sort by 'title' across search engines without regard
to internal engine-specific field names. 

bento_search is designed to allow code to be written agnostic of the search
provider, so you can switch out the search provider, minimizing dependent
code in your app that needs to be rewritten. As well as letting you get
started quick without reinventing the wheel and figuring out poorly
documented vendor API's yourself. 


## Usage

### Instantiate an engine, and search

When you instantiate an engine, you can provide configuration keys. There
are a few standard keys (see BentoSearch::SearchEngine), and others that
may be engine-specific. Some engine-specific keys (such as api auth keys) 
may be required for certain engines. 

    engine = BentoSearch::GoogleBooksEngine.new(:api_key => "my_gbs_api_key")
    results = engine.search("a query")
    
`results` are a BentoSearch::Results object, which acts like an array of
BentoSearch::Item objects, along with some meta-information about the
search itself (pagination keys, etc).  BentoSearch::Results and Item fields
are standardized accross engines. BentoSearch::Items provide semantic
values (title, author, etc.), as available from the particular engine. 

To see which engines come bundled with BentoSearch, and any special 
engine-specific instructions, look at BentoSearch source in `./app/search_engines`

### Register engines in global configuration

It can be convenient to register an engine in global configuration, and is 
required for certain functionality (like out-of-the-box AJAX loading). 

In an initializer in your app, like say `./config/initializers/bento_search.rb`:

    BentoSearch.register_engine("gbs") do |conf|
       conf.engine = "BentoSearch::GoogleBooksEngine"
       conf.api_key = "my_google_api_key"
       # any other configuration
    end
    
Then you can refer to it, for instance in a controller, by the id you registered:

    @results = BentoSearch.get_engine("gbs").search("my query")
    
### Display results

You can of course write your own code to display a BentoSearch::Results object
however you like. But BentoSearch comes with a helper method for displaying
a list of BentoSearch::Results in a standard way, using the bento_search
helper method. 

    <%= bento_search(@results) %>
    
### Fielded searching.

You can search by an internal engine-specific field name:

    google_books_engine.search("smith", :search_field => "inauthor")
    
Or, if the engine provides it, you can search by normalized semantic search
field type names:

    google_books_engine.search("smith", :semantic_earch_field => :title)
    
This will raise if an engine doesn't support that semantic search field. 
You can find out what fields a particular engine supports.

    BentoSearch::GoogleBooksEngine.search_keys # => internal keys
    BentoSearch::GoogleBooksEngine.semantic_search_keys 

You can also provide all arguments in a single hash when it's convenient
to do so:

    google_books_engine.search(:query => "smith", :search_field => "inauthor")
    
### Sorting

An engine advertises what sort types it supports:

    BentoSearch::GoogleBooksEngine.sort_definitions
   
That returns a hash, where the keys are sort identifiers, where possible
chosen from a standard list of semantics. (See list in config/i18n/en.yml,
bento_search.sort_keys). 

    google_books_engine.search("my query", :sort => "date_desc")
    
For help creating your UI, you can use built-in helper method:

    bento_sort_options(engine)
    #=> returns a Hash suitable as a second argument for rails
    # select_tag helper, with sort options and labels from I18n. 
        
    
### Pagination

You can tell the search engine how many items you want per-page, and 
use _either_ `:start` (0-based item offset) or `:page` (1-based page
offset) keys to paginate into the results. 

    results = google_books_engine.search("my query", :per_page => 20, :start => 40)
    results = google_books_engine.search("my query", :per_page => 20, :page => 2) # means same as above
    
An engine instance advertises it's maximum and default per-page values. 

    google_books_engine.max_per_page
    google_books_engine.default_per_age
    
For help creating your UI, you can ask a BentoSearch::Results for
`results.pagination`, which returns a BentoSearch::Results::Pagination
object which should be suitable for passing to [kaminari](https://github.com/amatsuda/kaminari)
`paginate`, or else have convenient methods for roll your own pagination UI. 
Kaminari's paginate method:

    <%= paginate results.pagination %> 
    
### Concurrent searching

If you're going to search 2 or more search engines at once, you'll want to execute
those searches concurrently. For instance, if GoogleBooks results take 2 second
to come in, and Scopus results take 3 seconds -- you don't want to first wait
the 2 second then wait the 3 seconds for a total of 5 -- you instead want
to execute concurrently in seperate threads, so the total wait time is the slowest
engine, not the sum of the engines. 

You can write your own logic using ruby threads to do this, but 
BentoSearch provides a multi-searching helper using [Celluloid](https://github.com/celluloid/celluloid)
to help you do this easily. Say, in a controller:

~~~~ruby
    # constructor takes id's registered with BentoSearch.register_engine
    searcher = BentoSearch::MultiSearcher.new(:gbs, :scopus, :summon)
    
    # Call 'start' with any parameters you would give to an_engine.search
    searcher.start("my query", :semantic_search_field => :author, :sort => "title")
    
    # At this point, all searches are executing asynchronously in seperate threads.
    # To get the results, blocking until all complete:
    @results = searcher.results
    
    # @results will be a hash, keyed by registered engine id, values
    # are BentoSearch::Results
~~~~

Even if you are only searching one engine, this may be useful to have the
search execute in a seperate thread, so you can continue doing other work
in the main thread (like search a local store of some kind outside of
bento_search)

You will need to add the 'celluloid' gem to your app to use this feature, 
BentoSearch doesn't automatically include the celluloid dependency right now
(should it?). 

For more info, see BentoSearch::MultiSearcher. 

### Delayed results loading via AJAX (actually more like AJAHtml)

BentoSearch provides some basic support for initially displaying a placeholder
progress spinner, and having Javascript call back to get the actual results. 

* **Setup Pre-requisites** 
    * In your `./config/routes.rb`, you need `BentoSearch::Routes.new(self).draw` in order
      to route to the ajax loader. 
    * In your asset pipeline, you must have `//= require 'bento_search/ajax_load` 
      to get JS for ajax loading. (or require 'bento_search' to get all bento_search JS)
* **Note** that this is not a panacea for a very slow search engine -- if the
search results take 20 seconds to come in, when the AJAX call back happens,
your Rails process _will_ be blocked from serving any other requests for that 20
seconds. In fact, that makes this feature of very limited applicability in general,
think carefully about what this will do for you. 
* **Beware** that there are some authorization considerations if your search
engine is not publically configurable, see BentoSearch::SearchController
for more details. 

You have have registered a configured engine globally, and given it the special
`:allow_routable_results` key. 

    BentoSearch.register_engine("gbs") do |conf|
      conf.api_key = "x"
      conf.allow_routable_results = true
    end
    
Now you can use the `bento_search` helper method with the registered id
and query, instead of with results as before, and with an option for
ajax auto-load. 

    <%= bento_search("gbs", :query => "my query", 
                     :semantic_search_field => :title,
                     :load => :ajax_auto) %>



### Item Decorators, and Links

You can configure Decorators, in the form of plain old ruby modules, to be
applied to BentoSearch::Items, on an engine-by-engine basis. These can modify,
add, or remove Item data, as well as over-ride some presentational methods.  

One common use for these Decorators is changing, adding, or removing links
associated with an item. For instance, to link to your local OpenURL 
link resolver.

BentoSearch::Items can have a main link associated with them (generally 
hyperlinked from title), as well as a list of additional links. Most engines
do not provide additional links by default, custom local Decorators would
be used to add them.

    BentoSearch.register_engine("something") do |conf|
       conf.engine = SomeEngine
       conf.item_decorators = [ SomeModule, OtherModule]
    end

See BentoSearch::Item for more information on decorators, and BentoSearch::Link
on links. 

## Planned Features

I am trying to keep BentoSearch as simple as it can be to conveniently meet
actual use cases.  Trying to avoid premature over-engineering, and pave
the cowpaths as needed. 

Probably:

* Support for display facets for engines that support such, as well as 
  search with limits from controlled vocabulary (ie, selected facet, but
  also may be supported by some engines that do not support facetting). 
* Support for multi-field, multi-entry-box 'advanced search' UI's, in
  a normalized cross-engine way. 
* More mindless support for displaying pagination UI with kaminari.

Other needs or suggestions?
  

## Developing

BentoSearch is fairly well covered by automated tests. We simply use Test::Unit.
Run tests with `rake test`. 

The testing environment was generated with `rails plugin new`, and includes
a dummy app used when testing at `./test/dummy`. 

For integration tests against live external search API's, we use the awesome
[VCR](https://github.com/myronmarston/vcr) gem to cache responses. 
To write your own Test::Unit tests using VCR, take note of the 
`test_with_cassette` method provided in `./test/support/test_with_cassette.rb`. 

Also note use of VCR.filter_sensitive_data to make sure your API keys
do not get saved in cached response in the repo, while still allowing
tests to be run against cached responses even for engines that require
auth. 

To re-generate cached responses, delete the relevant files in 
`./test/vcr_cassettes` and re-run tests. You may have to set an ENV
variable with your own API keys to re-run tests without cached response
like this. 

Also note `./test/support/mock_engine.rb`, a simple mock/dummy SearchEngine
implementation that can be used in other tests. 

Pull requests welcome.  Pull requests with additional search engine implementations
welcome. See more info on writing a BentoSearch::SearchEngine in the inline
docs in that file. 


