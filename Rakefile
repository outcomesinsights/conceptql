require "bundler/gem_tasks"
ENV['DATA_MODEL'] ||= 'omopv4_plus'

desc "Setup test database"
task :test_db_setup do
  require_relative 'test/db_setup'
end

desc "Setup test database"
task :test_db_teardown do
  require_relative 'test/db_teardown'
end

run_spec = lambda do |data_model|
  sh "DATA_MODEL=#{data_model} #{FileUtils::RUBY} test/all.rb"
end

desc "Run tests with omopv4_plus data model"
task :test_omopv4_plus do
  run_spec.call(:omopv4_plus)
end

desc "Run tests with gdm data model"
task :test_gdm do
  run_spec.call(:gdm)
end

desc "Run tests with omopv4 data model with coverage"
task :test_cov do
  ENV['COVERAGE'] = '1'
  run_spec.call(:omopv4_plus)
end

desc "Run tests with omopv4 data model"
task :default => :test_omopv4_plus
