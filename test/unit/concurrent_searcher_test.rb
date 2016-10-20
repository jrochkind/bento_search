require 'test_helper'

# Doesn't really test the concurrency, but basic smoke test with fake
# searchers.
class ConcurrentSearcherTest < ActiveSupport::TestCase
  setup do
    BentoSearch.register_engine("one") do |conf|
      conf.engine = "MockEngine"
    end
    BentoSearch.register_engine("two") do |conf|
      conf.engine = "MockEngine"
    end
    BentoSearch.register_engine("three") do |conf|
      conf.engine = "MockEngine"
    end
  end

  teardown do
    BentoSearch.reset_engine_registrations!
  end


  def test_concurrent_search
    searcher = BentoSearch::ConcurrentSearcher.new(:one, :two, :three)
    returnval = searcher.search("cancer")

    assert_same searcher, returnval

    results = searcher.results

    assert_kind_of Hash, results
    assert_equal ["one", "two", "three"].sort, results.keys.sort

    ["one", "two", "three"].each do |key|
      assert_kind_of BentoSearch::Results, results[key]
    end

    # call results again, we get the exact same hash back.
    new_results = searcher.results
    assert_kind_of Hash, new_results
    assert( results.equal? new_results )
  end




end
