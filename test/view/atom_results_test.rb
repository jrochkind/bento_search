require 'test_helper'

require 'nokogiri'

class AtomResultsTest < ActionView::TestCase
  @@namespaces = {
    "atom"        => "http://www.w3.org/2005/Atom",
    "opensearch"  => "http://a9.com/-/spec/opensearch/1.1/",
    "prism"       => ""
  }
  # Instead of using assert_select, we do it ourselves with nokogiri
  # for better namespace control.
  #
  # xml = Nokogiri::XML( rendered )
  # assert_node(xml, "atom:entry") do |matched_nodes|
  #   assert matched_node.first["attribute"] == "foo"
  # end
  def assert_node(xml, xpath, options = {})
    result = xml.xpath(xpath, @@namespaces)         
    
    assert result.length > 0, "Expected xpath '#{xpath}' to match in #{xml.to_s[0..200]}..."
    
    if options[:text]
      assert_equal options[:text], result.text.strip, "Expected #{options[:text]} as content of #{result.to_s[0..200]}"
    end
    
    yield result if block_given?
  end
  
  def setup
    @total_items = 1000
    @start       = 6
    @per_page    = 15
    
    
    @engine = BentoSearch::MockEngine.new(:total_items => @total_items)    
    @results = @engine.search("some query", :start => @start, :per_page => @per_page)
    
    # but fill the first result elements with some non-blank data to test
    @article_example = BentoSearch::ResultItem.new(
      :title => "An Article",
      :link => "http://example.org/main_link"
    )
     
    @results[0] = @article_example
  end
  
  def test_smoke_atom_validate
    # Validate under Atom schema. Should we validate under prism and dc schemas
    # too? Not sure if it makes sense, or if there's even a relevant schema
    # for how we're using em. So of just basic 'smoke' value. 
    render :template => "bento_search/atom_results", :locals => {:atom_results => @results}
    xml_response = Nokogiri::XML( rendered ) { |config| config.strict }
    
    atom_xsd_filepath = File.expand_path("../../support/atom.xsd.xml",  __FILE__)
    schema_xml        = Nokogiri::XML(File.read(atom_xsd_filepath))
    # modify to add processContents lax so it'll let us include elements from
    # external namespaces. 
    schema_xml.xpath("//xs:any[@namespace='##other']", {"xs" => "http://www.w3.org/2001/XMLSchema"}).each do |node|
      node["processContents"] = "lax"
    end    
    
    schema = Nokogiri::XML::Schema.from_document( schema_xml )
        
    assert_empty schema.validate(xml_response), "Validates with atom XSD schema"    
  end
  
  
  def test_feed_metadata
    render :template => "bento_search/atom_results", :locals => {:atom_results => @results}
    
    xml_response = Nokogiri::XML( rendered ) 
    
    assert_node(xml_response, "atom:feed") do |feed|            
      assert_node(feed, "atom:title")
      assert_node(feed, "atom:author")
      assert_node(feed, "atom:updated")
      
      assert_node(feed, "opensearch:totalResults", :text => @total_items.to_s)
      assert_node(feed, "opensearch:startIndex",   :text => @start.to_s)
      assert_node(feed, "opensearch:itemsPerPage", :text => @per_page.to_s)
    end
    
  end
  

  
  
end
