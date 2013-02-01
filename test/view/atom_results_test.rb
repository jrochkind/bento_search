require 'test_helper'

require 'nokogiri'

class AtomResultsTest < ActionView::TestCase
  include ActionView::Helpers::UrlHelper
  
  @@namespaces = {
    "atom"        => "http://www.w3.org/2005/Atom",
    "opensearch"  => "http://a9.com/-/spec/opensearch/1.1/",
    "prism"       => "http://prismstandard.org/namespaces/basic/2.1/",
    "dcterms"     => "http://purl.org/dc/terms/",
    "bibo"        => "http://purl.org/ontology/bibo/"
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
    @article = BentoSearch::ResultItem.new(
      :title      => "An Article", #
      :link       => "http://example.org/main_link", #
      :unique_id  => "UNIQUE_ID",
      :format     => "Article", #
      :format_str => "Uncontrolled format", #
      :language_code => "en", #
      :year       => "2004", #
      :volume     => "10", #
      :issue      => "1", #
      :start_page => "101", #
      :end_page   => "110", #
      :source_title => "Journal of Something", #
      :issn       => "12345678", #
      :doi        => "10.1000/182", #
      :abstract   => "This is an abstract with escaped > parts < ", #
      :authors => [ #
        BentoSearch::Author.new(:first => "John", :last => "Smith"),
        BentoSearch::Author.new(:display => "Jones, Jane")
      ],
      :other_links => [ #
        BentoSearch::Link.new(:url => "http://example.org/bare_link"),
        BentoSearch::Link.new(
          :url    => "http://example.org/label_and_type",
          :label  => "A link somewhere",      
          :type   => "application/pdf"
        ),
        BentoSearch::Link.new(
          :url    => "http://example.org/rel",
          :rel    => "something"
        )
      ]
    )
    @article_with_html_abstract = BentoSearch::ResultItem.new(
      :title    => "foo",
      :format   => "Article",
      :abstract => "This is <b>html</b>".html_safe
     )
    @article_with_full_date = BentoSearch::ResultItem.new(
      :title => "foo",
      :format => "Article",
      :publication_date => Date.new(2011, 5, 6)
    )
    @book = BentoSearch::ResultItem.new(
      :title     => "A Book",
      :format    => "Book",
      :publisher => "Some publisher",
      :isbn      => "123456789X",
      :oclcnum   => "12124345",
      :year      => "2004"
    )
    
    
     
    @results[0] = @article
    @results[1] = @article_with_html_abstract
    @results[3] = @article_with_full_date
    @results[4] = @book    
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
  
  def test_article_entry_example
    render :template => "bento_search/atom_results", :locals => {:atom_results => @results}    
    xml_response = Nokogiri::XML( rendered ) 
    
    assert_node(xml_response, "./atom:feed/atom:entry[1]") do |article|
      assert_node(article, "atom:title", :text => @article.title)  
      assert_node(article, "prism:coverDate", :text => @article.year)
      
      assert_node(article, "prism:issn", :text => @article.issn)
      assert_node(article, "prism:doi", :text => @article.doi)
      
      assert_node(article, "prism:volume", :text => @article.volume)
      assert_node(article, "prism:number",  :text => @article.issue)
      
      assert_node(article, "prism:startingPage", :text => @article.start_page)
      assert_node(article, "prism:endingPage",   :text => @article.end_page)
      
      assert_node(article, "prism:publicationName", :text => @article.source_title)
      
      abstract = article.at_xpath("atom:summary", @@namespaces)
      assert_present abstract, "Has an abstract"
      assert_equal "text", abstract["type"], "Abstract type text"
      assert_equal @article.abstract, abstract.text
      
      assert_node(article, "dcterms:language[@vocabulary='http://dbpedia.org/resource/ISO_639-1']", :text => @article.language_iso_639_1)
      assert_node(article, "dcterms:language[@vocabulary='http://dbpedia.org/resource/ISO_639-3']", :text => @article.language_iso_639_3)
      assert_node(article, "dcterms:language[not(@vocabulary)]", :text => @article.language_str)   
      
      assert_node(article, "dcterms:type[not(@vocabulary)]", :text => @article.format_str)
            
      assert_node(article, "dcterms:type[@vocabulary='http://schema.org/']", :text => @article.schema_org_type_url)
      assert_node(article, "dcterms:type[@vocabulary='http://purl.org/NET/bento_search/ontology']", :text => @article.format)
      
      # Just make sure right number of author elements, with right structure. 
      assert_node(article, "atom:author/atom:name") do |authors|
        assert_equal @article.authors.length, authors.length, "right number of author elements"
      end
      
      # Links. Main link is just rel=alternate
      assert_node(article, 
        "atom:link[@rel='alternate'][@href='#{@article.link}']")
      
      # other links also there, default rel=related
      assert_node(article, 
        "atom:link[@rel='related'][@type='application/pdf'][@title='A link somewhere'][@href='http://example.org/label_and_type']")
      assert_node(article,
        "atom:link[@rel='something'][@href='http://example.org/rel']")                  
    end    
            
  end
  
  
  def test_with_unique_id
    @results  = @engine.search("find")    
    @results[0] = BentoSearch::ResultItem.new(
      :title => "Something",      
      :unique_id => "a000:/01",
      :engine_id => "some_engine"
    )
    
    render :template => "bento_search/atom_results", :locals => {:atom_results => @results}    
    xml_response = Nokogiri::XML( rendered )
    
    with_unique_id = xml_response.xpath("./atom:feed/atom:entry", @@namespaces)[0]
    
    assert_node(with_unique_id, "atom:id") do |id|
      # based off of engine_id and unique_id
      assert_include id.text, "some_engine"
      assert_include id.text, "a000%3A%2F01"
    end      
  end
  
  def test_with_html_abstract
    render :template => "bento_search/atom_results", :locals => {:atom_results => @results}    
    xml_response = Nokogiri::XML( rendered )
    
    with_html_abstract = xml_response.xpath("./atom:feed/atom:entry", @@namespaces)[1]
    
    assert_node(with_html_abstract, "atom:summary[@type='html']", :text => @article_with_html_abstract.abstract.to_s)      
  end
  
  def test_book
    render :template => "bento_search/atom_results", :locals => {:atom_results => @results}    
    xml_response = Nokogiri::XML( rendered )
        
    book = xml_response.xpath("./atom:feed/atom:entry", @@namespaces)[4]
    
    assert_node(book, "dcterms:type[@vocabulary='http://purl.org/NET/bento_search/ontology']", :text => "Book")
    assert_node(book, "dcterms:type[@vocabulary='http://schema.org/']", :text => "http://schema.org/Book")
    
    assert_node(book, "dcterms:publisher", :text => @book.publisher)
    
    assert_node(book, "prism:isbn", :text => @book.isbn)
    
    assert_node(book, "bibo:oclcnum", :text => @book.oclcnum)
  end
  
  def test_with_full_date
    render :template => "bento_search/atom_results", :locals => {:atom_results => @results}    
    xml_response = Nokogiri::XML( rendered )
    
    with_full_date = xml_response.at_xpath("./atom:feed/atom:entry[4]", @@namespaces)
    
    assert_node(with_full_date, "prism:coverDate", :text => "2011-05-06")    
  end

  def test_nil_results
    # should render a more or less empty atom response for
    # nil results, convenient to not raise on nil
    render :template => "bento_search/atom_results", :locals => {:atom_results => nil}   
  end
  
  def test_locals_for_feed_name_and_author
    render( :template => "bento_search/atom_results", 
      :locals => {:atom_results => @results, 
                  :feed_name => "My Feed",
                  :feed_author_name => "ACME Seed And Feed Products"}
    )
                  
    xml_response = Nokogiri::XML( rendered )
    
    assert_node(xml_response, "./atom:feed/atom:title", :text => "My Feed")
    assert_node(xml_response, "./atom:feed/atom:author/atom:name", :text => "ACME Seed And Feed Products")
  end
  
  def test_html_in_title_stripped
    results = BentoSearch::Results.new
    results << BentoSearch::ResultItem.new(
      :title => "html <b>title</b>".html_safe
    )
    
    render(:template => "bento_search/atom_results", :locals => {:atom_results => results})
    xml_response = Nokogiri::XML( rendered )
        
    assert_node(xml_response, "./atom:feed/atom:entry[1]/atom:title", :text => "html title")
    
  end
  
  
end
