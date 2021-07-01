source "http://rubygems.org"

# Declare your gem's dependencies in bento_search.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# jquery-rails is used by the dummy application
gem "jquery-rails"

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# debugger in custom group so we can exclude it from travis,
# don't neccesarily want to exclude all 'development
group "manual_development" do
  gem 'debugger', :platform => :mri_19
  gem 'byebug',   :platform => [:mri_21, :mri_22, :mri_23]
end

# For allowing testing under multiple Rails versions from travis or command
# line. Can't test Rails5 under MRI less than 2.2.2.
rails_version = if ENV['RAILS_VERSION_SPEC'] && !ENV['RAILS_VERSION_SPEC'].empty?
  ENV['RAILS_VERSION_SPEC'].dup
else
  "6.1"
end

gem 'rails', "~> #{rails_version}"

if Gem::Version.new(rails_version) > Gem::Version.new("4.2.999999")
  # Only for Rails5, to restore tests we need, gah.
  group "test" do
    gem 'rails-controller-testing', '~> 1.0'
  end
end

if Gem::Version.new(rails_version) < Gem::Version.new("5.0")
  # Previous to Rails5, we need to include concurrent-ruby explicitly,
  # in 5.x it's a dependency of Rails.
  group "test" do
    gem 'concurrent-ruby', '~> 1.0'
  end
end

if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new("2.0")
  # Can't quite explain this one, but for ruby 1.9....
  # https://github.com/rails/rails/issues/24749
  gem 'mime-types', '2.6.2'

  # New versions of public-suffix require newer ruby than 1.9.3,
  # lock to 1.4.x one to test under 1.9.3
  gem 'public_suffix', '~> 1.4.0'
end

if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new("2.1")
  gem 'nokogiri', '< 1.7'
end

gem "sqlite3", :platform => [:ruby, :mswin, :mingw]

# for JRuby
gem "activerecord-jdbcsqlite3-adapter", :platform => :jruby
if Gem::Version.new(rails_version).release < Gem::Version.new("5.0")
  # https://github.com/jruby/activerecord-jdbc-adapter/issues/859
  gem "activerecord-jdbc-adapter", "~> 1.3.0", :platform => :jruby
end
