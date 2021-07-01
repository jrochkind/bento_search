$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "bento_search/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "bento_search"
  s.version     = BentoSearch::VERSION
  s.authors     = ["Jonathan Rochkind"]
  s.homepage    = "http://github.com/jrochkind/bento_search"
  s.summary     = "An abstraction/normalization layer for querying and displaying results for external search engines, in Ruby on Rails."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]

  s.test_files = Dir["test/**/*"] - Dir["test/dummy/log/**/*"] - Dir["test/dummy/tmp/**/*"] - Dir["test/db/*.sqlite"] - Dir["test/dummy/db/**/*.sqlite3"]

  s.add_dependency "rails", ">= 3.2.3", "< 6"
  # s.add_dependency "jquery-rails"
  s.add_dependency "confstruct", "~> 1.0"
  s.add_dependency "httpclient", ">= 2.2.5", "< 3.0.0"
  s.add_dependency "multi_json", ">= 1.0.4", "< 2.0"
  s.add_dependency "nokogiri"
  s.add_dependency "openurl", ">= 0.3.1", "< 1.1"
  s.add_dependency "summon"
  s.add_dependency "language_list", "~> 1.0" # ISO 639 language codes
  s.add_dependency "htmlentities" # replace htmlentities with straight unicode text, used to change HTML to plain text

  s.add_development_dependency "vcr", "~> 2.4"
  s.add_development_dependency "webmock", "~> 1.11.0"
end
