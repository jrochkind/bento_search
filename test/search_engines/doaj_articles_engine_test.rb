require 'test_helper'
require 'uri'
require 'cgi'

class DoajArticlesEngineTest < ActiveSupport::TestCase
  extend TestWithCassette

  def setup    
    @engine = BentoSearch::DoajArticlesEngine.new
    # tell it not to send our bad API key
  end

  test_with_cassette("basic search", :doaj_articles) do
    results = @engine.search("Breast cancer patients with lobular cancer more commonly have a father than a mother diagnosed with cancer")

    assert_kind_of BentoSearch::Results, results    
    assert ! results.failed?

    assert_not_nil results.total_items
    assert_equal 0, results.start
    assert_equal 10, results.per_page
    
    assert_not_empty results
    
    first = results.first

    assert_present first.unique_id
    assert_equal "Article", first.format

    assert_present first.title

    assert_not_empty    first.authors
    assert_not_empty    first.authors.first.display


    assert_present first.source_title
    assert_present first.issn
    assert_present first.volume
    assert_present first.issue

    assert_present first.start_page

    assert_present first.year
    assert_present first.publication_date

    assert_present first.abstract
    assert first.abstract.html_safe?

    assert_present first.link
    assert first.link_is_fulltext?
  end

  test_with_cassette("pagination", :doaj_articles) do
    results = @engine.search("cancer", :per_page => 20, :page => 3)
    
    assert ! results.failed?
    
    assert_equal 20, results.length
    
    assert_equal 20, results.size
    assert_equal 40, results.start
    assert_equal 20, results.per_page
  end

  test_with_cassette("catches errors", :doaj_articles) do
    @engine.base_url = "https://doaj.org/api/v1/search/articles_bad_url/"

    results = @engine.search("something")

    assert results.failed?
    assert_kind_of Hash, results.error
    assert_present results.error[:message]
    assert_present results.error[:status]    
  end

  test_with_cassette("live #get(identifier) round trip", :doaj_articles) do
    results = @engine.search("cancer")

    assert (! results.failed?)

    item = @engine.get( results.first.unique_id )

    assert_not_nil  item
    assert_kind_of  BentoSearch::ResultItem, item
  end

  test_with_cassette("live get(identifier) raises on no results", :doaj_articles) do
    assert_raises(BentoSearch::NotFound) { item = @engine.get( "no_such_id" ) }
  end

  test_with_cassette("multifield author-title", :doaj_articles) do
    results = @engine.search(:query => {
      :author => "Huxtable",
      :title => '"Global Unions as the Missing Link in Labour Movement Studies"'
    })

    assert ! results.failed?

    assert_present results
  end

  test_with_cassette("complex multi-field", :doaj_articles) do
    results = @engine.search(:query => {
      nil     => "Anti-war",
      :author => "Caffentzis",
      :title  => '"Respect Your Enemies" first rule of peace',
      :source_title => '"Revista Theomai"'
    })

    assert ! results.failed?

    assert_equal 1, results.total_items
    assert_equal 1, results.count

    result = results.first

    assert_equal "Revista Theomai", result.source_title
    assert_equal "Respect Your Enemies - The First Rule of Peace: An Essay Addressed to the U. S. Anti-war Movement", result.title
  end

  test "escapes spaces how DOAJ likes it" do
    url = @engine.args_to_search_url(:query => "One Two")
    parsed = URI.parse(url)
    last_path = parsed.path.split('/').last

    # %20 not + for space.
    # %2B for "+""
    assert_equal "%2BOne%20%2BTwo", last_path
  end

  test "escapes special chars" do
    url = @engine.args_to_search_url(:query => "Me: And/Or You")

    parsed = URI.parse(url)

    last_path = parsed.path.split('/').last
    last_path = CGI.unescape(last_path)

    assert_equal "+Me\\: +And\\\/Or +You", last_path
  end

  test "generates fielded searches" do
    url = @engine.args_to_search_url(:query => "Smith", :search_field => "bibjson.author.name")

    parsed = URI.parse(url)

    last_path = parsed.path.split('/').last
    last_path = CGI.unescape(last_path)

    assert_equal "+bibjson.author.name:(+Smith)", last_path
  end

  test "generates multi-field search" do
    url = @engine.args_to_search_url(:query => {
      nil     => "Anti-war",
      :author => "Caffentzis",
      :title  => '"Respect Your Enemies" first rule of peace'
    })

    parsed = URI.parse(url)

    last_path = parsed.path.split('/').last
    last_path = CGI.unescape(last_path)

    assert_equal '+Anti\-war +author:(+Caffentzis) +title:(+"Respect Your Enemies" +first +rule +of +peace)', last_path
  end

  test "does not escape double quotes" do
    # we want to allow them for phrase searching
    url = @engine.args_to_search_url(:query => '"This is a phrase"')

    parsed = URI.parse(url)

    last_path = parsed.path.split('/').last
    last_path = CGI.unescape(last_path)

    assert_equal '+"This is a phrase"', last_path
  end

  test "multi-token fielded search" do
    url = @engine.args_to_search_url(:query => 'apple orange "strawberry banana"', :search_field => "bibjson.title")

    parsed = URI.parse(url)

    last_path = parsed.path.split('/').last
    last_path = CGI.unescape(last_path)

    assert_equal '+bibjson.title:(+apple +orange +"strawberry banana")', last_path
  end

  test "adds sort to query url" do
    url = @engine.args_to_search_url(:query => "cancer", :sort => 'date_desc')

    parsed = URI.parse(url)
    query  = CGI.parse(parsed.query)

    assert_equal ["article.created_date:desc"], query["sort"]
  end

  end