require 'test_helper'

require 'cgi'
require 'uri'

#
# To run queries live (without recorded VCR), you must have ENV variables
# set: SUMMON_ACCESS_ID and SUMMON_SECRET_KEY


class SummonEngineTest < ActiveSupport::TestCase
  extend TestWithCassette

  @@access_id   = (ENV['SUMMON_ACCESS_ID']  || "DUMMY_ACCESS_ID")
  @@secret_key  = (ENV['SUMMON_SECRET_KEY'] || "DUMMY_SECRET_KEY")

  VCR.configure do |c|
    c.filter_sensitive_data("DUMMY_ACCESS_ID", :summon)  { @@access_id }
    c.filter_sensitive_data("DUMMY_SECRET_KEY", :summon) { @@secret_key }
  end

  def setup
    @config = {
      'access_id' => @@access_id,
      'secret_key' => @@secret_key
    }
    @engine = BentoSearch::SummonEngine.new(@config)
  end

  def test_request_construction
    uri, headers = @engine.construct_request(:query => "elephant's")


    assert_present headers
    assert_present headers["Content-Type"]
    assert_present headers["Accept"]
    assert_present headers["x-summon-date"]
    assert_present headers["Authorization"]


    assert_present uri
    query_params = CGI.parse( URI.parse(uri).query )
    assert_present query_params["s.q"]
  end

  def test_request_construction_with_lang
    engine = BentoSearch::SummonEngine.new(@config.merge(:lang => 'en'))

    uri, headers = engine.construct_request(:query => "cancer")

    assert_present uri
    query_params = CGI.parse( URI.parse(uri).query )
    assert_equal ["en"], query_params["s.l"]
  end

  def test_summon_escape
    uri, headers = @engine.construct_request(:query=> "Foo: A) \\Bar \"a phrase\"")

    query_params = CGI.parse( URI.parse(uri).query )

    assert_present (query = query_params["s.q"].first)

    # double backslashes are escaping for ruby string literal,
    # it's actually only a single backslash in output.
    assert_equal "Foo\\: A\\) \\\\Bar \"a phrase\"", query
  end

  def test_sort_construction
    uri, headers = @engine.construct_request(:query => "elephants", :sort => "date_desc")

    query_params = CGI.parse( URI.parse(uri).query )

    assert_present (sort = query_params["s.sort"].first )

    assert_equal("PublicationDate:desc", sort)

  end

  def test_fielded_search_construction
    uri, headers = @engine.construct_request(:query => "eleph)ants", :search_field => "SomeField")

    query_params = CGI.parse( URI.parse(uri).query )

    assert_equal "SomeField:(eleph\\\)ants)", query_params["s.q"].first
  end

  def test_pagination_construction
    uri, headers = @engine.construct_request(:query => "elephants_per_page", :per_page => 20, :page => 2)

    query_params = CGI.parse( URI.parse(uri).query )

    assert_equal "20", query_params["s.ps"].first
    assert_equal "2",  query_params["s.pn"].first
  end

  def test_authenticated_user_construction
    uri, headers = @engine.construct_request(:query => "elephants", :auth => true)

    query_params = CGI.parse( URI.parse(uri).query )

    assert_present query_params['s.role']
    assert_equal "authenticated", query_params['s.role'].first
  end

  def test_construct_fixed_param_config
    engine = BentoSearch::SummonEngine.new('access_id' => @@access_id,
      'secret_key' => @@secret_key,
      'fixed_params' => {
        "s.fvf" => ["ContentType,Newspaper Article,true", "ContentType,Book,true"],
        "s.role" => "authenticated"
      })

    uri, headers = engine.construct_request(:query => "elephants")

    query_params = CGI.parse( URI.parse(uri).query )

    assert_include query_params["s.fvf"], "ContentType,Newspaper Article,true"
    assert_include query_params["s.fvf"], "ContentType,Book,true"
    assert_include query_params["s.role"], "authenticated"

  end

  def test_construct_no_highlighting
    engine = BentoSearch::SummonEngine.new('access_id' => @@access_id,
      'secret_key' => @@secret_key,
      'highlighting' => false)

    uri, headers = engine.construct_request(:query => "elephants")

    query_params = CGI.parse( URI.parse(uri).query )

    assert_include query_params['s.hl'], "false"
  end


  def test_construct_summon_params_on_search
    engine = BentoSearch::SummonEngine.new('access_id' => @@access_id,
      'secret_key' => @@secret_key
    )

    uri, headers = engine.construct_request(:query => "elephants", :summon_params => {"a" => "a", "b" => ["b1", "b2"]})

    query_params = CGI.parse( URI.parse(uri).query )

    assert_equal    1,    query_params["a"].try(:length)
    assert_include  query_params["a"], "a"

    assert_equal    2,    query_params["b"].try(:length)
    assert_include  query_params["b"], "b1"
    assert_include  query_params["b"], "b2"
  end

  def test_construct_peer_reviewed_only
    uri, headers = @engine.construct_request(:query => "foo", :peer_reviewed_only => "true")

    query_params = CGI.parse( URI.parse(uri).query )

    assert_kind_of Array, query_params["s.fvf"]
    assert_include query_params["s.fvf"], "IsPeerReviewed,true"
  end

  def test_construct_pubyear_range
    uri, headers = @engine.construct_request(:query => "foo", :pubyear_start => "1990", :pubyear_end => 2000)

    query_params = CGI.parse( URI.parse(uri).query )

    assert_include query_params["s.rf"], "PublicationDate,1990:2000"
  end

  def test_construct_pubyear_range_open_bottom
    uri, headers = @engine.construct_request(:query => "foo", :pubyear_end => 2000)

    query_params = CGI.parse( URI.parse(uri).query )

    assert_include query_params["s.rf"], "PublicationDate,*:2000"
  end

  def test_construct_pubyear_range_open_top
    uri, headers = @engine.construct_request(:query => "foo", :pubyear_start => "1990")

    query_params = CGI.parse( URI.parse(uri).query )

    assert_include query_params["s.rf"], "PublicationDate,1990:*"
  end


  test_with_cassette("bad auth", :summon) do
    engine = BentoSearch::SummonEngine.new('access_id' => "bad_access_id", :secret_key => 'bad_secret_key')

    results = engine.search("elephants")

    assert results.failed?, "should return #failed?"
  end


  test_with_cassette("search", :summon) do
    results = @engine.search("elephants")

    assert ! results.failed?

    assert_present results

    assert_present results.total_items
    assert_not_equal 0, results.total_items

    first = results.first

    assert_present first.title
    assert_present first.format_str

    # just smoke test to make sure it's set to something
    assert_not_nil first.link_is_fulltext?

    assert_present  first.unique_id

    # Make sure we have the summon.original_data hash
    assert_kind_of Hash,  first.custom_data["summon.original_data"]
  end

  test_with_cassette("proper tags for snippets", :summon) do
    results = @engine.search("cancer")

    first = results.first

    assert_include first.title, '<b class="bento_search_highlight">'
    assert_include first.title, '</b>'

    assert first.title.html_safe?, "title is HTML safe"
  end

  test_with_cassette("snippets array", :summon) do
    results = @engine.search("noam chomsky")

    assert_present results.first

    assert_present results.first.snippets

    assert_include results.first.snippets.first, '<b class="bento_search_highlight">'
  end

  test_with_cassette("live #get(id)", :summon) do
    results = @engine.search("cancer")

    assert_present results

    item = @engine.get(results.first.unique_id)

    assert_not_nil item
    assert_kind_of BentoSearch::ResultItem, item

    assert_equal results.first.unique_id, item.unique_id
  end

  test_with_cassette("live get(id) on non-existing id", :summon) do
    assert_raise(BentoSearch::NotFound) do
      item = @engine.get("NONE SUCH")
    end
  end

end
