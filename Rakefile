require "bundler/gem_tasks"

desc "Setup test database"
task :test_db_setup do
  require_relative 'test/db_setup'
end

desc "Setup test database"
task :test_db_teardown do
  require_relative 'test/db_teardown'
end

desc "Run tests"
task :test do
  sh "#{FileUtils::RUBY} test/all.rb"
end

desc "Run tests"
task :default => :test
