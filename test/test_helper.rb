# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb",  __FILE__)

# we insist on minitest, when only the best will do. 
# Rails will build on top of it if it's there. 
require 'minitest/unit'

require "rails/test_help"

Rails.backtrace_cleaner.remove_silencers!

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# Load fixtures from the engine
if ActiveSupport::TestCase.method_defined?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
end

# VCR is used to 'record' HTTP interactions with
# third party services used in tests, and play em
# back. Useful for efficiency, also useful for
# testing code against API's that not everyone
# has access to -- the responses can be cached
# and re-used. 
require 'vcr'
require 'webmock'

# To allow us to do real HTTP requests in a VCR.turned_off, we
# have to tell webmock to let us. 
WebMock.allow_net_connect!

VCR.configure do |c|
  c.cassette_library_dir = 'test/vcr_cassettes'
  # webmock needed for HTTPClient testing
  c.hook_into :webmock 
end

# Silly way to not have to rewrite all our tests if we
# temporarily disable VCR, make VCR.use_cassette a no-op
# instead of no-such-method. 
if ! defined? VCR
  module VCR
    def self.use_cassette(*args)
      yield
    end
  end
end

# re-open to add 
# some custom assertions, that used to be in mini-test, or that
# we wanted to add. 
class ActiveSupport::TestCase

  def assert_present(object, msg = nil)
    msg ||= "expected #{object} to be #present?"
    assert(object.present?, msg)
  end

  def assert_blank(object, msg = nil)
    msg ||= "expected #{object} to be #blank?"
    assert object.blank?, msg
  end

end