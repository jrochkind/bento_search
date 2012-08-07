require 'test_helper'

class EdsEngineTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  @@user_id   = (ENV['EDS_USER_ID'] || 'DUMMY_USER_ID')
  @@password  = (ENV['EDS_PASSWORD'] || 'DUMMY_PWD')
  @@profile   = (ENV['EDS_PROFILE'] || 'edsapi')
  
  
  VCR.configure do |c|
    c.filter_sensitive_data("DUMMY_USER_ID", :eds) { @@user_id }
    c.filter_sensitive_data("DUMMY_PWD", :eds) { @@password }
  end

  def setup
    # Class-level remembered auth token messes up our VCR-recording,
    # since one test will try to use an auth token fetched by a different
    # test. For testing, blank out the cache before each test. 
    BentoSearch::EdsEngine.remembered_auth = nil

    
    @engine = BentoSearch::EdsEngine.new(:user_id => @@user_id, :password => @@password, :profile => @@profile, :auth => true)
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
      
      assert_present first.format_str
  end
  
  
end

