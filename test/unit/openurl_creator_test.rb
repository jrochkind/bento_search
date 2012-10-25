require 'test_helper'

class OpenurlCreatorTest < ActiveSupport::TestCase
  
  def test_create_article
    item = BentoSearch::ResultItem.new(
        :format => "Article",
        :title => "My Title",
        :subtitle => "A Nice One",
        :year => 2012,
        :volume => "10",
        :issue => "1",
        :start_page => "1",
        :end_page => "100",
        :journal_title => "Journal of Fakes",
        :issn => "12345678",
        :doi => "XXXX",                        
      )
    item.authors << BentoSearch::Author.new(:first => "John", :last => "Smith")
    
    r = BentoSearch::OpenurlCreator.new(item).to_openurl.referent
    
    assert_equal "journal",     r.format
    
    assert_equal "article",      r.metadata["genre"]
    
    assert_equal "2012",          r.metadata["date"]
    assert_equal "10",          r.metadata["volume"]
    assert_equal "1",           r.metadata["issue"]
    assert_equal "1",           r.metadata["spage"]
    assert_equal "100",         r.metadata["epage"]
    assert_equal "Journal of Fakes", r.metadata["jtitle"]
    assert_equal "12345678",    r.metadata["issn"]
    assert_include r.identifiers, "info:doi:XXXX"
    
    assert_equal "John",        r.metadata["aufirst"]
    assert_equal "Smith",       r.metadata["aulast"]
    assert_equal "Smith, J",    r.metadata["au"]
    
    assert_equal "My Title: A Nice One",  r.metadata["atitle"]
        
  end
  
  def test_numeric_conversion
    item = BentoSearch::ResultItem.new(
        :format => "Article",
        :title => "My Title",
        :subtitle => "A Nice One",
        :year => 2012,
        :volume => 10,
        :issue => 1,
        :start_page => 1,
        :end_page => 100,        
        :issn => "12345678",                              
      )
    
    
    r = BentoSearch::OpenurlCreator.new(item).to_openurl.referent
    
    assert_equal "1", r.metadata["issue"]
  end
  
  def test_create_book
    item = BentoSearch::ResultItem.new(
      :format => "Book",
      :title => "My Book",
      :year => 2012,
      :publisher => "Brothers, Inc.",
      :isbn => "1234567X"
      )
    
    item.authors << BentoSearch::Author.new(:first => "John", :last => "Smith")
    
    r = BentoSearch::OpenurlCreator.new(item).to_openurl.referent
      
    assert_equal "book", r.format
    
    assert_equal "My Book",         r.metadata["btitle"]
    assert_equal "Brothers, Inc.",  r.metadata["pub"]
    assert_equal "1234567X",        r.metadata["isbn"]
    assert_equal "2012",              r.metadata["date"]
      
  end
  
  def test_create_hardcoded_kev
    item = BentoSearch::ResultItem.new(
      :format => "Book",
      :title => "Something",
      :openurl_kev_co => "rft.title=Foo+Bar&rft.au=Smith"
      )
    
    r = BentoSearch::OpenurlCreator.new(item).to_openurl.referent
    
    assert_equal  "journal",    r.format
    assert_equal  "Foo Bar",    r.metadata["title"]
    assert_equal  "Smith",      r.metadata["au"]

  end
  
  def test_result_item_to_openurl
    item = BentoSearch::ResultItem.new(
      :format => "Book",
      :title => "Something",
      :openurl_kev_co => "rft.title=Foo+Bar&rft.au=Smith"
      )
    
    openurl = item.to_openurl
    
    assert_kind_of OpenURL::ContextObject, openurl
  end
  
  def test_strip_tags     
    item = BentoSearch::ResultItem.new(      
      :title => "<b>My Title</b>".html_safe,
      :year => 2012,
      :isbn => "XXXX",                        
      )
    
    openurl = item.to_openurl
    
    assert_equal "My Title", openurl.referent.metadata["title"]
  end
  
  
  def test_publication_date
    item = BentoSearch::ResultItem.new(      
      :title => "some title",
      :year => 2012,
      :publication_date => Date.new(2012, 5, 1)             
      )
    
    openurl = item.to_openurl
    
    assert_equal "2012-05-01", openurl.referent.metadata["date"]     
  end
  
  def test_oclcnum
    item = BentoSearch::ResultItem.new(      
      :title => "some title",
      :oclcnum => "12345"                   
      )
    
    openurl = item.to_openurl
    
    # The legal way:
    assert_include openurl.referent.identifiers, 'info:oclcnum/12345'
    # Not actually legal but common practice:
    assert_equal '12345',openurl.referent.metadata["oclcnum"] 
  end
  
  
end
