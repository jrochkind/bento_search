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
  "7.1"
end

gem 'rails', "~> #{rails_version}"

gem "sqlite3", :platform => [:ruby, :mswin, :mingw]

# for JRuby
gem "activerecord-jdbcsqlite3-adapter", :platform => :jruby
