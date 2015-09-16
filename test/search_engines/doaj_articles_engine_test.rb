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

  test_with_cassette("fielded search", :doaj_articles) do
    results = @engine.search('Code4Lib Journal', :semantic_search_field => :publication_name)

    assert ! results.failed?

    results.each do |result|
      assert_equal "Code4Lib Journal", result.source_title
    end
  end

  test "escapes special chars" do
    url = @engine.args_to_search_url(:query => "Me: And/Or You")

    parsed = URI.parse(url)

    last_path = parsed.path.split('/').last
    last_path = CGI.unescape(last_path)

    assert_equal "Me\\: And\\\/Or You", last_path
  end

  test "adds sort to query url" do
    url = @engine.args_to_search_url(:query => "cancer", :sort => 'date_desc')

    parsed = URI.parse(url)
    query  = CGI.parse(parsed.query)

    assert_equal ["article.created_date:desc"], query["sort"]
  end

  end