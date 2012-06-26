= BentoSearch

bento_search provides an abstraction/normalization layer for querying and 
displaying results for external search engines. 

It is focused on use cases for academic libraries, but may be useful in generic
cases too. Initially, engine adapters are planned to be provided for: 
Google Books, Scopus, SerialSolutions Summon, Ex Libris Primo, 
and EBSCO Discovery Service. (Possibly ThomsonReuters Web of Knowledge). Most
of these search engines require a vendor license to use. 

bento_search could be considered building blocks for a type of 'federated
search' functionality, but it does not and will never support merging results
from multiple engines into one result set. It is meant to support displaying the
first few results from multiple engines on one page, "bento box" style (as
named by Tito Sierra@NCSU), as well as more expanded single-search-on-a-page
uses. 

bento_search provides abstract functionality for pagination, sorting, 
and single-field-specified queries. Faceting, limiting, and 'advanced'
multi-field searches are not yet supported, but planned. Not all
search engine adapters support all features.  Search engine adapters can
declare search fields and sort options with 'semantics', so you can for
instance search or sort by 'title' across search engines without regard
to internal engine-specific field names. 

== Usage

=== Instantiate and engine, and search

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

=== Register engines in global configuration

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
    
=== Display results

You can of course write your own code to display a BentoSearch::Results object
however you like. But BentoSearch comes with a helper method for displaying
a list of BentoSearch::Results in a standard way, using the bento_search
helper method. 

    <%= bento_search(@results) %>
    
=== Fielded searching.

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
    
=== Sorting

An engine advertises what sort types it supports:

   BentoSearch::GoogleBooksEngine.sort_definitions
   
That returns a hash, where the keys are sort identifiers, where possible
chosen from a standard list of semantics. (See list in config/i18n/en.yml,
bento_search.sort_keys). 

    google_books_engine.search("my query", :sort => "date_desc")
    
=== Pagination

You can tell the search engine how many items you want per-page, and 
use _either_ `:start` (0-based item offset) or `:page` (1-based page
offset) keys to paginate into the results. 

    google_books_engine.search("my query", :per_page => 20, :start => 40)
    google_books_engine.search("my query", :per_page => 20, :page => 3)
    
An engine advertises it's maximum and default per-page values. 

    BentoSearch::GoogleBooksEngine.max_per_page
    BentoSearch::GoogleBooksEngine.default_per_age
    
=== Concurrent searching

If you're going to search 2 or more search engines at once, you'll want to execute
those searches concurrently. For instance, if GoogleBooks results take 2 second
to come in, and Scopus results take 3 seconds -- you don't want to first wait
the 1 second then wait the 3 seconds for a total of 4 -- you instead want
to execute concurrently in seperate threads, so the total wait time is the slowest
engine, not the sum of the engines. 

You can write your own logic using ruby threads to do this, but 
BentoSearch provides a multi-searching helper using [Celluloid](https://github.com/celluloid/celluloid)
to help you do this easily. Say, in a controller:

    # constructor takes id's registered with BentoSearch.register_engine
    searcher = BentoSearch::MultiSearcher.new(:gbs, :scopus, :summon)
    
    # Call 'start' with any parameters you would give to an_engine.search
    searcher.start("my query", :semantic_search_field => :author, :sort => "title")
    
    # At this point, all searches are executing asynchronously in seperate threads.
    # To get the results, blocking until all complete:
    @results = searcher.results
    
    # @results will be a hash, keyed by registered engine id, values
    # are BentoSearch::Results
    
For more info, see BentoSearch::MultiSearcher. 

=== Delayed results loading via AJAX (actually more like AJAHtml)

== Planned Features

== Developing

    



