require 'test_helper'


class RISCreatorTest < ActiveSupport::TestCase
  RISCreator = BentoSearch::RISCreator
  ResultItem = BentoSearch::ResultItem
  Author     = BentoSearch::Author
  
  # Parses an RIS file into a simpel data structure easier to test:
  # an array of two element arrays, where each two element array is 
  # (tag, field).  This method MAY also assert that the thing basically
  # looks like a proper RIS file. 
  def ris_parse(str)
    assert_match /\A\r\n/, str, "RIS records begin with \r\n seperator"
    str.gsub!(/\A(\r\n)+/, '') # remove any at the beginning, multiple are fine
    
    assert_match /\r\n\Z/, str, "Our RIS records end up with \r\n so they are concat-able with blank lines in between"
    str.gsub!(/(\r\n)+\Z/, '') # remove any at the end, multiple are fine
    
    lines = str.split("\r\n", -1)
            
    assert_present lines, "RIS files are composed of multiple lines seperated by \r\n"
            
    # trim blank lines off beginning or end, they're allowed. Also "ER" tag
    # off the end, make sure it's there then trim it. 
    assert_equal "ER  - ", lines.last, "RIS records end in `ER  - `"
    lines.pop # throw it away now. 
    
    return lines.collect do |line|            
      line =~ /^([A-Z][A-Z0-9])  - (.*)$/
      tag = $1 ; value = $2
      assert (tag.present? && value.present?), "Individual RIS lines are composed of `TG  - VALUE`, not `#{line}`"
      [tag, value]
    end
  end
  
  
  @@article = ResultItem.new(
    :format => "Article",
    :title => "Some Article",
    :source_title => "Some Journal",
    :issn => "12345678",
    :volume => "10",
    :issue => "3",
    :start_page => "100",
    :end_page => "110",
    :doi => '10.1000/182',
    :abstract => "This is an abstract",
    :authors => [
      Author.new(:first => "John", :last => "Smith", :middle => "Q"),
      Author.new(:first => "Maria", :last => "Lopez"),
      Author.new(:display => "Some Guy")
    ]
  )
  
  @@article_with_full_date = ResultItem.new(
    :format => "Article",
    :title => "Something",
    :source_title => "Some Magazine",
    :start_page => "123",
    :publication_date => Date.new(2011,9,1)
  )
  
  @@book = ResultItem.new(
    :format => "Book",
    :title => "Some Book",
    :isbn => "1234567890",
    :publisher => "Some Publisher",
    :year => "1990",
    :authors => [
      Author.new(:first => "John", :last => "Smith", :middle => "Q")
    ]
  )
  
  @@book_chapter = ResultItem.new(
    :format   => :book_item,
    :title    => 'Some Chapter',
    :source_title => "Book Title",
    :year     => '1991',
    :publisher => "Some Pub",
    :start_page => '10',
    :authors => [
      Author.new(:first => "John", :last => "Smith", :middle => "Q")
    ]
  )
  
  @@dissertation = ResultItem.new(
    :format => :dissertation,
    :title => "Areoformation and the new science",
    :publisher => "University of Mars",
    :year => "2150",
    :authors => [
      Author.new(:display => "mztlbplk q. frakdf")
    ]
  )


  def test_article        
    lines = ris_parse RISCreator.new(@@article).export    
    
    assert_includes lines, ['TY', 'JOUR']
    assert_includes lines, ['TI', @@article.title]
    assert_includes lines, ['T2', @@article.source_title]
    assert_includes lines, ['SN', @@article.issn]
    assert_includes lines, ['VL', @@article.volume]
    assert_includes lines, ['IS', @@article.issue]
    assert_includes lines, ['SP', @@article.start_page]    
    assert_includes lines, ['EP', @@article.end_page]
    assert_includes lines, ['DO', @@article.doi]
    assert_includes lines, ['AB', @@article.abstract]

    assert_includes lines, ['AU', "Smith, John Q."]
    assert_includes lines, ['AU', "Lopez, Maria"]
    assert_includes lines, ['AU', "Some Guy"]
  end
  
  def test_book
    lines = ris_parse RISCreator.new(@@book).export
    
    assert_includes lines, ['TY', 'BOOK']
    assert_includes lines, ['TI', @@book.title]
    assert_includes lines, ['PY', @@book.year]
    assert_includes lines, ['PB', @@book.publisher]
    assert_includes lines, ['SN', @@book.isbn]
    
    assert_includes lines, ['AU', "Smith, John Q."]
  end
  
  def test_book_chapter
    lines = ris_parse RISCreator.new(@@book_chapter).export
    
    assert_includes lines, ['TY', 'CHAP']
    
    assert_includes lines, ['TI', @@book_chapter.title]
    assert_includes lines, ['T2', @@book_chapter.source_title]
    assert_includes lines, ['PY', @@book_chapter.year]
    assert_includes lines, ['PB', @@book_chapter.publisher]
    assert_includes lines, ['SP', @@book_chapter.start_page]
  end
  
  def test_dissertation
    lines = ris_parse RISCreator.new(@@dissertation).export
    
    assert_includes lines, ['TY', 'THES']
    
    assert_includes lines, ['TI', @@dissertation.title]
    assert_includes lines, ['PB', @@dissertation.publisher]
    assert_includes lines, ['PY', @@dissertation.year]
  end
  
  def test_article_with_full_date
    lines = ris_parse RISCreator.new(@@article_with_full_date).export
    
    assert_includes lines, ['TY', 'JOUR']
    
    assert_includes lines, ['DA', '2011/09/01']    
  end
  
    
end
