
# An object intended to be compatible with kaminari for pagination,
# although kaminari doesn't doc/spec exactly what you need, so might
# break in future. Could be useful for your own custom pagination too. 
#
# You don't normally create one of these yourself, you get one returned
# from Results#pagination
#
#
#  <%= paginate @results.pagination %>
class BentoSearch::Results::Pagination
  
  # first arg is results.total_items, second is result
  # of normalized_args from searchresults. 
  #
  # We don't do the page/start normalization calc here,
  # we count on them both being passed in, already calculated
  # by normalize_arguments in SearchResults. Expects :page, 0-based
  # :start, and 1-based :per_page to all be passed in in initializer. 
  def initialize(total, normalized_args)
    normalized_args ||= {} # in some error cases, we end up with nil
    
    @total_count = total || 0
    @per_page = normalized_args[:per_page] || 10
    @current_page = normalized_args[:page]  || 1
    @start_record = (normalized_args[:start] || 0) + 1 
  end
    
  def current_page
    @current_page
  end
  
  # 1-based start, suitable for showing to user
  # Can be 0 for empty result set. 
  def start_record
    [@start_record, count_records].min
  end
  
  # 1-based last record in window, suitable for showing to user.
  # Can be 0 for empty result set.   
  def end_record
    [start_record + per_page - 1, count_records].min
  end
  
  # If nil is passed in, will normalize to 0 so things doing math
  # comparisons won't raise. 
  def count_records
    @total_count
  end
  # Kaminari in different versions wants this called SO MANY things. 
  alias count count_records
  alias total_count count_records
  
  def total_pages
    (@total_count.to_f / @per_page).ceil
  end
  # kaminari wants both, weird. 
  alias num_pages total_pages

  
  def first_page?
    current_page == 1
  end
  
  def last_page?
    current_page >= total_pages
  end
     
  def per_page
    @per_page
  end
  # kaminari wants it called this.
  alias limit_value per_page

  # Recent kaminari's have an offset_value which is 0-based, unlike
  # our 1-based @start_record. Le Sigh. 
  def offset_value
    @start_record - 1
  end
  
end
