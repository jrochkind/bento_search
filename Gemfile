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

# Can't test rails5 under mri 2.3. Hey, we get Rails 4 testing like this too...
if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new("2.3")
  gem 'rails', "~> 4.2"
else
  # Only for Rails5, to restore tests we need, gah.
  group "test" do
    gem 'rails-controller-testing', '~> 1.0'
  end
end

if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new("2.0")
  # Can't quite explain this one, but for ruby 1.9....
  # https://github.com/rails/rails/issues/24749
  gem 'mime-types', '2.6.2'
end


gem "sqlite3", :platform => [:ruby, :mswin, :mingw]

# for JRuby

gem "jdbc-sqlite3", :platform => :jruby
