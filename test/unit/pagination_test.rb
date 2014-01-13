require 'test_helper'

# Test the BentoSearch::Results::Pagination object
class PaginationTest < ActiveSupport::TestCase
  Pagination = BentoSearch::Results::Pagination
  
  def test_implicit_page
    pag = Pagination.new(100, {:per_page => 10})
    
    assert_equal 1, pag.current_page
    assert_equal 1, pag.start_record
    assert_equal 10, pag.end_record
    assert pag.first_page?
    assert ! pag.last_page?
    assert_equal 100, pag.count_records
    assert_equal 100, pag.total_count # some kaminari's want it called this instead. 
    assert_equal 10, pag.total_pages
    assert_equal 10, pag.per_page    
  end
  
  def test_last_page
    pag = Pagination.new(100, {:page => 5, :start => 80, :per_page => 20})
    
    assert_equal 5, pag.current_page
    assert_equal 81, pag.start_record
    assert_equal 80, pag.offset_value
    assert_equal 100, pag.end_record
    assert ! pag.first_page?
    assert pag.last_page?
    assert_equal 100, pag.count_records
    assert_equal 5, pag.total_pages
    assert_equal 20, pag.per_page
  end
  
  def test_uneven_pages
    pag = Pagination.new(95, {:page => 10, :start => 90, :per_page => 10})
    
    assert_equal 10, pag.current_page
    assert_equal 91, pag.start_record
    assert_equal 95, pag.end_record
    assert ! pag.first_page?
    assert pag.last_page?
    assert_equal 95, pag.count_records
    assert_equal 10, pag.total_pages
    assert_equal 10, pag.per_page
  end
  
  def test_empty_args
    pag = Pagination.new(nil, {})
    
    assert_equal 1, pag.current_page
    assert_equal 0, pag.start_record
    assert_equal 0, pag.end_record
    assert pag.first_page?
    assert pag.last_page?
    assert_equal 0, pag.count_records
    assert_equal 0, pag.total_pages
  end
  
  
end
