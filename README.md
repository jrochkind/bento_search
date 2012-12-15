# BentoSearch

[![Build Status](https://secure.travis-ci.org/jrochkind/bento_search.png)](http://travis-ci.org/jrochkind/bento_search)

(Fairly robust and stable at this point, but still pre-1.0 release, may
be some breaking api changes before 1.0, but probably not too many, it's
looking pretty good). 

bento_search provides an abstraction/normalization layer for querying and 
displaying results for external search engines, in Ruby on Rails. Requires
Rails3 and tested only under ruby 1.9.3. 

### Goals: To help you

* **Get up and running as quickly as possible** with searching and displaying
  results from a  third-party service. Solutions to idiosyncracies and
  undocumented workarounds are encoded in a shared codebase, which abstracts
  everything to a good, simple code API giving you building blocks to focus
  on your needs, not the search service's problems. 
* Let you switch out one search service for another in an already built
  application with as little code rewriting as possible. **Avoid vendor lock-in**. 
* Give you the harness to **write adapters for new search services**, without
  having to rewrite common general functionality, just focus on the interface
  with the new API you want to support. 

bento_search is focused on use cases for academic libraries, which is mainly
evidenced by the search engine adapters currently included, and by the
generalized domain models including fields that matter in our domain (issn,
vol/issue/page, etc), and some targetted functionality (OpenURL generation). 
But it ought to be useful for more general basic use
cases too (we include a google site search adapter for instance). 

Adapters currently included in bento_search

* Google Books (requires free api key)
* Scopus (requires license)
* Serial Solution Summon (requires license)
* Ex Libris Primo (requires license)
* EBSCO Discovery Service (requires license)
* EBSCOHost 'traditional' API (requires license)
* WorldCat Search (requires OCLC membership to get api key)
* Google Site Search (requires sign-up for more than 100 searches/day)




### Scope of functionality

bento_search could be considered building blocks for a type of 'federated
search' functionality, but it does not and will never support merging results
from multiple engines into one result set. It is meant to support displaying the
first few results from multiple engines on one page, "bento box" style (as
named by Tito Sierra@NCSU), as well as more expanded single-search-on-a-page
uses. 

* bento_search provides abstract functionality for pagination, sorting, 
and single-field-specified queries. Faceting, generalized limiting, and 'advanced'
multi-field searches are not yet supported, but possibly will be built
out in the future. 

Not all search engine adapters support all features.  Some engines offer
engine-specific features, such as limiting. Search engine adapters can
declare search fields and sort options with 'semantics', so you can for
instance search or sort by 'title' across search engines without regard
to internal engine-specific field names. 

bento_search is designed to allow code to be written agnostic of the search
provider, so you can switch out the search provider. 

See code-level api documentation for more details, especially at
BentoSearch::SearchEngine. http://rubydoc.info/gems/bento_search/frames/

An example app using BentoSearch and showing it's features is
available at http://github.com/jrochkind/sample_megasearch
There is a short screencast showing that sample app in action here: http://screencast.com/t/JLS0lclrBZU

## Usage Examples

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

See also the [Customizing Results Display wiki page](https://github.com/jrochkind/bento_search/wiki/Customizing-Results-Display). 
    
### Fielded searching.

You can search by an internal engine-specific field name:

    google_books_engine.search("smith", :search_field => "inauthor")
    
Or, if the engine provides it, you can search by normalized semantic search
field type names:

    google_books_engine.search("smith", :semantic_search_field => :title)
    
You can find out what fields a particular engine supports.

    google_books_engine.search_keys # => internal keys
    google_books_engine.semantic_search_keys 
    
A helper method for generating an html select of search field options is
available in `bento_field_hash_for`, check it out. 

You can also provide all arguments in a single hash when it's convenient
to do so:

    google_books_engine.search(:query => "smith", :search_field => "inauthor")

Search fields that are not recognized (semantic or internal) will normally
be ignored, but set `:unrecognized_search_field => :raise` in configuration
or search arg to get an ArgumentError instead. 
    
### Sorting

An engine advertises what sort types it supports:

    google_books_engine.sort_keys
   
An array of sort identifiers, where possible
chosen from a standard list of semantics. (See list in `./config/i18n/en.yml`,
`bento_search.sort_keys`). 

    google_books_engine.search("my query", :sort => "date_desc")
    
For help creating your UI, you can use built-in helper method, perhaps with Rails helper
options_for_select:

    <%= options_for_select( bento_sort_hash_for(engine), params[:sort] ) %>
    
        
    
### Pagination

You can tell the search engine how many items you want per-page, and 
use _either_ `:start` (0-based item offset) or `:page` (1-based page
offset) keys to paginate into the results. 

    results = google_books_engine.search("my query", :per_page => 20, :start => 40)
    results = google_books_engine.search("my query", :per_page => 20, :page => 2) # means same as above
    
An engine instance advertises it's maximum per-page values. 

    google_books_engine.max_per_page
    
bento_search fixes the default per_page at 10.     
    
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
    
    # Call 'search' with any parameters you would give to an_engine.search
    searcher.search("my query", :semantic_search_field => :author, :sort => "title")
    
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
BentoSearch doesn't automatically include the celluloid dependency. Note
that Celluloid uses multi-threading in such a way that you might need
to turn Rails config.cache_classes=true even in development.
 

For more info, see BentoSearch::MultiSearcher. 

### Delayed results loading via AJAX (actually more like AJAHtml)

BentoSearch provides some basic support for initially displaying a placeholder
progress spinner, and having Javascript call back to get the actual results. 

It's not a panacea for pathologically slow search results, and can be tricky
for results that need access controls. But it can be useful
in some situations, both for automatic on-page-load ajax loading, and triggered
ajax loading. 

See the [wiki page](https://github.com/jrochkind/bento_search/wiki/AJAX-results-loading)
for more info. 

                     
                     
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

See BentoSearch::Link for more info on links. (TODO: Better docs/examples
on decorators). 

## OpenURL and metadata

Academic library uses often need openurl links from scholarly citations. One of
the design goals of bento_search is to produce standardized normalized BentoSearch::ResultItem
models, with sufficient semantics for translation to other formats. 

See ResultItem#to_openurl_kev (string URL query encoding of OpenURL), and 
ResultItem#to_openurl (a [ruby OpenURL gem](https://github.com/openurl/openurl) object). 

Quality may vary, depending on how well the particular engine adapter captures semantics,
especially the format/type of results (See bento_search's internal format/type vocabulary
documented at ResultItem#format). As well as how well the #to_openurl routine
handles all edge cases (OpenURL can be weird). As edge cases are discovered, they
can be solved. 

See `./app/item_decorators/bento_search/openurl_add_other_link.rb` for an example
of using item decorators to add a link to your openurl resover to an item when
displayed. 

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

Also note `BentoSearch::MockEngine`, a simple mock/dummy SearchEngine
implementation that can be used in other tests, including in client
software where convenient. 

Pull requests welcome.  Pull requests with additional search engine implementations
welcome. See more info on writing a BentoSearch::SearchEngine in the inline
docs in that file. 



