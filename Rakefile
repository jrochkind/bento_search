#!/usr/bin/env rake
begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end
begin
  require 'rdoc/task'
rescue LoadError
  require 'rdoc/rdoc'
  require 'rake/rdoctask'
  RDoc::Task = Rake::RDocTask
end

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'BentoSearch'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

APP_RAKEFILE = File.expand_path("../test/dummy/Rakefile", __FILE__)
load 'rails/tasks/engine.rake'

load 'rails/tasks/statistics.rake'

require 'bundler/gem_tasks'


if Gem::Version.new(Rails.version) > Gem::Version.new('4.2.99999')
  desc "Run tests"
  task :test do
    Rake::Task["app:test"].invoke
  end
  # use built-in Rails test command
  # task :test do
  #   require "rails/test_unit/minitest_plugin"
  #   #$: << File.expand_path('test', ENGINE_ROOT)
  #   Minitest.rake_run([])

  #   # require 'rails/engine/commands_tasks'
  #   # Rails::Engine::CommandsTasks.new("").run_command!('test')
  # end
else
  # old rails4 style
  require 'rake/testtask'

  Rake::TestTask.new(:test) do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.pattern = 'test/**/*_test.rb'
    t.verbose = false
    t.warning = false
  end
end


task :default => :test
