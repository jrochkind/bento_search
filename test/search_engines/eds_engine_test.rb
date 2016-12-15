require 'test_helper'

class EdsEngineTest < ActiveSupport::TestCase
  extend TestWithCassette

  @@user_id   = (ENV['EDS_USER_ID'] || 'DUMMY_USER_ID')
  @@password  = (ENV['EDS_PASSWORD'] || 'DUMMY_PWD')
  @@profile   = (ENV['EDS_PROFILE'] || 'wsapi')
  # something where the first hit will be from catalog for the profile above
  @@catalog_result_query = (ENV['EDS_CATALOG_RESULT_QUERY'] || 'New York exposed the gilded age police scandal that launched the progressive era Daniel Czitrom')
  @@catalog_ebook_result_query = (ENV['EDS_CATALOG_EBOOK_RESULT_QUERY'] || 'Stakeholder forum on federal wetlands mitigation environmental law institute')
  @@catalog_custom_result_query = (ENV['EDS_CATALOG_CUSTOM_RESULT_QUERY'] || 'Drafting New York Civil-Litigation Documents Part XXIV Summary-Judgment Motions Continued')
  VCR.configure do |c|
    c.filter_sensitive_data("DUMMY_USER_ID", :eds) { @@user_id }
    c.filter_sensitive_data("DUMMY_PWD", :eds) { @@password }
  end

  def setup
    # Class-level remembered auth token messes up our VCR-recording,
    # since one test will try to use an auth token fetched by a different
    # test. For testing, blank out the cache before each test.
    BentoSearch::EdsEngine.remembered_auth = nil

    @config = {:user_id => @@user_id, :password => @@password, :profile => @@profile, :auth => true}
    @engine = BentoSearch::EdsEngine.new(@config)
  end

  test "construct simple search, with comma escaping" do
    url = @engine.construct_search_url(:query => "foo, bar,baz")

    query_params = CGI.parse( URI.parse(url).query )

    assert_equal ["all"], query_params["searchmode"]

    assert_equal ["detailed"], query_params["view"]

    assert_equal ["AND,foo  bar baz"], query_params["query"]
  end

  test "only_source_types config" do
    engine = BentoSearch::EdsEngine.new( @config.merge(:only_source_types => [
      "Academic Journals", "Magazines"
      ]))

    url = engine.construct_search_url(:query => "cancer", :per_page => 10)

    query_params = CGI.parse( URI.parse(url).query )

    # should be
    # facetfilter=1,SourceType:Academic Journals,SourceType:Magazines
    # but with value query encoded

    assert_equal 1, query_params["facetfilter"].length

    facetfilter = query_params["facetfilter"].first

    parts = facetfilter.split(",")

    assert_equal 3, parts.length

    assert_equal "1", parts.first

    assert_includes parts, "SourceType:Academic Journals"
    assert_includes parts, "SourceType:Magazines"
  end

  def test_has_http_timeout_set
    assert_equal BentoSearch::EdsEngine::HttpTimeout, @engine.http_client.receive_timeout
    assert_equal BentoSearch::EdsEngine::HttpTimeout, @engine.http_client.send_timeout
    assert_equal BentoSearch::EdsEngine::HttpTimeout, @engine.http_client.connect_timeout
  end


  test_with_cassette("get_auth_token failure", :eds) do
    engine = BentoSearch::EdsEngine.new(:user_id => "bad", :password => "bad", :profile => "bad")
    exception = assert_raise(BentoSearch::EdsEngine::EdsCommException) do
      token = engine.get_auth_token
    end

    assert_present exception.http_status
    assert_present exception.http_body
  end

  test_with_cassette("get_auth_token", :eds) do
    token = @engine.get_auth_token

    assert_present token
  end

  # No idea why VCR is having buggy problems with record and playback of this request
  # We'll emcompass it in the get_with_auth test
  #
  #test_with_cassette("with_session", :eds, :match_requests_on => [:method, :uri, :headers, :body]) do
  #  @engine.with_session do |session_token|
  #    assert_present session_token
  #  end
  #end

  test_with_cassette("get_with_auth", :eds) do
    @engine.with_session do |session_token|
      assert_present session_token

      # Coudln't get 'info' request to work even as a test, let's
      # try a simple search.
      url = "#{@engine.configuration.base_url}info"
      response = @engine.get_with_auth(url, session_token)

      assert_present response
      assert_kind_of Nokogiri::XML::Document, response

      assert_nil response.at_xpath("//ErrorNumber"), "no error report in result"
    end
  end

  test_with_cassette("get_with_auth recovers from bad auth", :eds) do
      @engine.with_session do |session_token|
        BentoSearch::EdsEngine.remembered_auth = "BAD"

        url = "#{@engine.configuration.base_url}info"
        response = @engine.get_with_auth(url, session_token)

        assert_present response
        assert_kind_of Nokogiri::XML::Document, response

        assert_nil response.at_xpath("//ErrorNumber"), "no error report in result"
      end

      BentoSearch::EdsEngine.remembered_auth = nil
  end

  test_with_cassette("basic search smoke test", :eds) do
      results = @engine.search("cancer")

      assert_present results

      assert_present results.total_items

      first = results.first

      assert_present first.title
      assert first.title.html_safe? # yeah, for now we use EDS html

      assert_present first.abstract
      assert_present first.abstract.html_safe?

      assert_present first.custom_data["citation_blob"]

      assert_present first.source_title
      assert_present first.issn
      assert_present first.volume
      assert_present first.issue
      assert_present first.year
      assert_present first.publication_date
      assert_present first.start_page
      assert_present first.end_page

      assert_present first.doi

      assert_present first.format_str

      assert_present first.unique_id
      # EDS id is db name, colon, accession number
      assert_match /.+\:.+/, first.unique_id
  end

  test_with_cassette("catalog query", :eds) do
    results = @engine.search(@@catalog_result_query)

    cat_result = results.first

    assert_present cat_result.custom_data[:holdings]
    assert cat_result.custom_data[:holdings].all? { |h| h.location.present? && h.call_number.present? }
  end

  test_with_cassette("catalog ebook query", :eds) do
    result = @engine.search(@@catalog_ebook_result_query).first

    assert_present result.other_links
  end

  test_with_cassette("FullText CustomLink", :eds) do
    result = @engine.search(@@catalog_custom_result_query).first
    assert_present result
    assert result.other_links.any? { |r| r.label.present? && r.label != "Link" && r.url.present? && URI::regexp =~ r.url && r.rel == "alternate"}
  end
end

