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


module TestWithCassette
    def test_with_cassette(name, group = nil, vcr_options ={}, &block)
      # cribbed from Rails and modified for VCR
      # https://github.com/rails/rails/blob/b451de0d6de4df6bc66b274cec73b919f823d5ae/activesupport/lib/active_support/testing/declarative.rb#L25
      
      test_name_safe = name.gsub(/\s+/,'_')
      
      test_method_name = "test_#{test_name_safe}".to_sym
      
      raise "#{test_method_name} is already defined in #{self}" if methods.include?(test_method_name)
      
      cassette_name = vcr_options.delete(:cassette)
      unless cassette_name
        # calculate default cassette name from test name
        cassette_name = test_name_safe
        # put in group subdir if group
        cassette_name = "#{group}/#{cassette_name}" if group
      end
      
      # default tag with groupname, can be over-ridden. 
      vcr_options = {:tag => group}.merge(vcr_options) if group

      if block_given?
        define_method(test_method_name) do
          VCR.use_cassette(cassette_name , vcr_options) do
            instance_eval &block
          end
        end
      else
        define_method(test_method_name) do
          flunk "No implementation provided for #{name}"
        end
      end
    end
end  


