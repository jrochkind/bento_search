# BentoSearch

[![CI Build Status](https://github.com/jrochkind/bento_search/actions/workflows/ruby.yml/badge.svg)](https://github.com/jrochkind/bento_search/actions/workflows/ruby.yml)
[![Gem Version](https://badge.fury.io/rb/bento_search.png)](http://badge.fury.io/rb/bento_search)

bento_search provides an abstraction/normalization layer for querying and
displaying results from external search engines, in Ruby on Rails. Works with
Rails 5.2 - 6.1, ruby 2.5 through 3.0.

### Goals: To help you

* **Get up and running as quickly as possible** with searching and displaying
  results from a  third-party service. Simple common code API, with idiosyncracies and
  undocumented workarounds abstracted away.
* Let you switch out one search service for another in an already built
  application with as little code rewriting as possible. **Avoid vendor lock-in**.
* Give you the harness to **write adapters for new search services**, without
  having to rewrite common general functionality, just focus on the interface
  with the new API you want to support.

bento_search is focused on use cases for academic libraries; the shared
model for search results includes including fields that matter in our domain (issn,
vol/issue/page, etc), although they ought to have what's needed for general
basic use too. There is some targetted functionality for academic library/publishing use
(eg OpenURL generation).

Adapters currently included in bento_search

* [Google Books](https://books.google.com/) (requires free api key)
* [Scopus](http://www.elsevier.com/solutions/scopus) (requires license)
* [Serial Solution Summon](http://www.proquest.com/products-services/The-Summon-Service.html) (requires license)
* [Ex Libris Primo](http://www.exlibrisgroup.com/category/PrimoOverview) (requires license)
* [EBSCO Discovery Service](https://www.ebscohost.com/discovery) (requires license)
* [EBSCOHost](https://www.ebscohost.com/) 'traditional' API (requires license)
* [WorldCat Search](https://www.worldcat.org/) (requires OCLC membership to get api key)
* [Google Site Search](https://www.google.com/work/search/products/gss.html) (requires sign-up for more than 100 searches/day)
* [JournalTOCs](http://www.journaltocs.hw.ac.uk/) (limited support for fetching current articles by ISSN, free but requires registration)
* [Directory of Open Access Journals (DOAJ)](https://doaj.org/) article search. (free, no registration required)




### Scope of functionality

bento_search could be considered building blocks for a type of 'federated
search' functionality, but it does not and will never support merging results
from multiple engines into one result set. It is meant to support displaying the
first few results from multiple engines on one page, "bento box" style (as
named by Tito Sierra@NCSU), as well as more expanded single-search-on-a-page
uses -- or back-end functionality supporting features that are not straight discovery.

* bento_search provides abstract functionality for pagination, sorting,
and single-field-specified queries. Faceting and generalized limiting are
not yet supported, but possibly will be built out in the future.

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

~~~~ruby
    engine = BentoSearch::GoogleBooksEngine.new(:api_key => "my_gbs_api_key")
    results = engine.search("a query")
~~~~

`results` are a [BentoSearch::Results](./app/models/bento_search/results.rb) object, which acts like an array of
[BentoSearch::ResultItem](./app/models/bento_search/result_item.rb) objects, along with some meta-information about the
search itself (pagination keys, etc).  BentoSearch::Results and Item fields
are standardized across engines. BentoSearch::Items provide semantic
values (title, author, etc.), as available from the particular engine.

To see which engines come bundled with BentoSearch, and any special
engine-specific instructions, look at BentoSearch source in [`./app/search_engines/bento_search`](./app/search_engines/bento_search)

### Register engines in global configuration

It can be convenient to register an engine in global configuration, and is
required for certain functionality (like out-of-the-box AJAX loading).

In an initializer in your app, like say `./config/initializers/bento_search.rb`:

~~~~ruby
    BentoSearch.register_engine("gbs") do |conf|
       conf.engine = "BentoSearch::GoogleBooksEngine"
       conf.api_key = "my_google_api_key"
       # any other configuration
    end
~~~~

Then you can refer to it, for instance in a controller, by the id you registered:

~~~~ruby
    @results = BentoSearch.get_engine("gbs").search("my query")
~~~~

### Display results

You can of course write your own code to display a BentoSearch::Results object
however you like. But BentoSearch comes with a helper method for displaying
a list of BentoSearch::Results in a standard way, using the bento_search
helper method.

~~~~ruby
    <%= bento_search @results %>
~~~~

See also the [Customizing Results Display wiki page](https://github.com/jrochkind/bento_search/wiki/Customizing-Results-Display).

### Fielded searching.

You can search by an internal engine-specific field name:

~~~~ruby
    google_books_engine.search("smith", :search_field => "inauthor")
~~~~

Or, if the engine provides it, you can search by normalized semantic search
field type names:

~~~~ruby
    google_books_engine.search("smith", :semantic_search_field => :title)
~~~~

You can find out what fields a particular engine supports.

~~~~ruby
    google_books_engine.search_keys # => internal keys
    google_books_engine.semantic_search_keys
~~~~

A helper method for generating an html select of search field options is
available in `bento_field_hash_for`, check it out.

You can also provide all arguments in a single hash when it's convenient
to do so:

~~~~ruby
    google_books_engine.search(:query => "smith", :search_field => "inauthor")
~~~~

Search fields that are not recognized (semantic or internal) will normally
be ignored, but set `:unrecognized_search_field => :raise` in configuration
or search arg to get an ArgumentError instead.

### Sorting

An engine advertises what sort types it supports:

~~~~ruby
    google_books_engine.sort_keys
~~~~

An array of sort identifiers, where possible
chosen from a standard list of semantics. (See list in `./config/i18n/en.yml`,
`bento_search.sort_keys`).

~~~~ruby
    google_books_engine.search("my query", :sort => "date_desc")
~~~~

For help creating your UI, you can use built-in helper method, perhaps with Rails helper
options_for_select:

~~~~ruby
    <%= options_for_select( bento_sort_hash_for(engine), params[:sort] ) %>
~~~~


### Pagination

You can tell the search engine how many items you want per-page, and
use _either_ `:start` (0-based item offset) or `:page` (1-based page
offset) keys to paginate into the results.

~~~~ruby
    results = google_books_engine.search("my query", :per_page => 20, :start => 40)
    results = google_books_engine.search("my query", :per_page => 20, :page => 2) # means same as above
~~~~

An engine instance advertises it's maximum per-page values.

~~~~ruby
    google_books_engine.max_per_page
~~~~

bento_search fixes the default per_page at 10.

For help creating your UI, you can ask a BentoSearch::Results for
`results.pagination`, which returns a [BentoSearch::Results::Pagination](app/models/bento_search/results/pagination.rb)
object which should be suitable for passing to [kaminari](https://github.com/amatsuda/kaminari)
`paginate`, or else have convenient methods for roll your own pagination UI.
Kaminari's paginate method:

~~~~ruby
    <%= paginate results.pagination %>
~~~~

### Multi-field search

Some search engines support-multi field searching, an engine advertises if it does:

    engine_instance.multi_field_searching? # => `true` or `false`

The bento_search multi-field search feature always combines multiple
fields with boolean 'and' (intersection). You call a multi-field search
with a :query hash argument whose value is a hash of search-fields and
queries:

    engine.search(:query => {
      :title  => '"Reflections on the History of Debt Resistance"',
      :author => 'Caffentzis'
    })

The search field keys can be either semantic_search_field names, or internal
engine search fields, or a combination. If the key matches a semantic search field
declared for the engine, that will be preferred.

This can be used to expose a multi-field search to users, and the `bento_field_hash_for`
helper method might be helpful in creating your UI. But this is also useful for looking
up known-item citations -- either by author/title, or issn/volume/issue/page, or doi, or
anything else -- as back-end support for various possible functions.

### Concurrent searching

If you're going to search 2 or more search engines at once, you'll want to execute
those searches concurrently. For instance, if GoogleBooks results take 2 second
to come in, and Scopus results take 3 seconds -- you don't want to first wait
the 2 second then wait the 3 seconds for a total of 5 -- you instead want
to execute concurrently in seperate threads, so the total wait time is the slowest
engine, not the sum of the engines.

You can write your own logic using ruby threads to do this, but
BentoSearch provides a multi-searching helper using [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby)
to help you do this easily. Say, in a controller:

~~~~ruby
    # constructor takes id's registered with BentoSearch.register_engine
    searcher = BentoSearch::ConcurentSearcher.new(:gbs, :scopus, :summon)

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

If you are using a Rails previous to 5.x, you will have to add the
`concurrent-ruby` gem to your `Gemfile` (It's already a dependency of
Rails5).

If you are using Rails5, ConcurrentSearcher uses new Rails API that
should make development-mode class reloading work fine even with
the ConcurrentSearcher's concurrency.

For more info, see [BentoSearch::ConcurrentSearcher](./app/models/bento_search/concurrent_searcher.rb).




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
be used to add them. See [wiki on display cusotmization](https://github.com/jrochkind/bento_search/wiki/Customizing-Results-Display)
for more info on decorators, and [BentoSearch::Link](app/models/bento_search/link.rb)
for fields.

### OpenURL and metadata

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

See [`./app/item_decorators/bento_search/openurl_add_other_link.rb`](./app/item_decorators/bento_search/openurl_add_other_link.rb)
for an example of using item decorators to add a link to your openurl resover to an item when
displayed.

### Exporting (eg as RIS) and get by unique_id

A class is included to convert an individual BentoSearch::ResultItem to
the RIS format, suitable for import into EndNote, Refworks, etc.

~~~ruby
    ris_data = RISCreator.new( bento_item ).export
~~~

Accomodating actual exports into the transactional flow of a web app can be
tricky, and often requires use of the `result_item#unique_id` and
`engine.get( unique_id )` features. See the wiki on [exports and #unique_id](https://github.com/jrochkind/bento_search/wiki/Exports-and-the-get-by-unique_id-feature)

### Machine-readable serialization in Atom

Translation of any BentoSearch::Results to an Atom response that is enhanced to
include nearly all the elements of each BentoSearch::ResultItem, so can serves
well as machine-readable api response in general, not just for Atom feed readers.

You can use the  [`bento_search/atom_results`](./app/views/bento_search/atom_results.atom.builder) view template, perhaps
in your action method like so:

~~~ruby
# ...
respond_to do |format|
   format.html # default view
   format.atom do
      render( :template => "bento_search/atom_results",
              :locals   => {
                 :atom_results     => @results,
                 :feed_name        => "Acme results",
                 :feed_author_name => "MyCorp"
              }
      )
end
~~~

There are additional details that might matter to you, for more info see the
[wiki page](https://github.com/jrochkind/bento_search/wiki/Machine-Readable-Serialization-With-Atom)

### Round-Trip Serialization to JSON

You can serialize BentoSearch::Results to a simple straightforward JSON structure, and de-serialize
them back into BentoSearch::Results.

~~~ruby
json_str          = results.dump_to_json
copy_of_results   = BentoSearch::Results.load_json(json_str)
~~~

Search context (query, start, per_page) are not serialized, and will be lost
on de-serialization.

Unlike the Atom serialization, **the JSON serialization is of internal data
state, without decoration.** Configuration context is not serialized.

However, the engine_id is included in serialization if present,
and configuration from the specified engine
will be re-assigned on de-serialization.  This means if the configuration
changed between serialization and de-serialization, you get the new stuff
assigned on de-serialization.

The use case guiding JSON serialization is storage somewhere, and
round-trip de-serialization in the current app context.

If you want to take de-serialized results that did not have an engine_id,
or set configuration on them to a different engine (registered or not) you can:

~~~ruby
  restored = BentoSearch::Results.load_json(json_str)
  some_engine.fill_in_search_metadata_for(restored)

  # restored Results will have configuration (engine_id, decorators, etc)
  # set to those configured on some_engine
~~~

If you want a serialization to be consumed by something other than an
app using the bento_search gem, as an API, we recommend the [Atom serialization](https://github.com/jrochkind/bento_search/wiki/Machine-Readable-Serialization-With-Atom)
instead.

## Planned Features

I am trying to keep BentoSearch as simple as it can be to conveniently meet
actual use cases.  Trying to avoid premature over-engineering, and pave
the cowpaths as needed.

Probably:

* Support for display facets for engines that support such, as well as
  search with limits from controlled vocabulary (ie, selected facet, but
  also may be supported by some engines that do not support facetting).

Other needs or suggestions?

## Backwards compat

We are going to try to be strictly backwards compatible with all post 1.0
releases that do not increment the major version number (semantic versioning).

As a general rule, we're going to let our tests enforce this -- if a test has
to be changed to pass with new code, that's a very strong sign that it is
not a backwards-compat change, and you should think _very_ carefully to
be sure it is an exception to this rule before changing any existing tests
for new functionality.

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



