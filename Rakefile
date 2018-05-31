begin
  require "bundler/gem_tasks"
rescue LoadError
end

ENV['CONCEPTQL_DATA_MODEL'] ||= 'omopv4_plus'

desc "Setup test database"
task :test_db_setup do
  require_relative 'test/db_setup'
end

desc "Setup test database"
task :test_db_teardown do
  require_relative 'test/db_teardown'
end

run_spec = lambda do |data_model|
  sh "CONCEPTQL_DATA_MODEL=#{data_model} #{FileUtils::RUBY} test/all.rb"
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

desc "Ingests client's CSV file for custom vocabularies"
task :make_vocabs_csv, [:csv_path] do |t, args|
  require "conceptql"
  require "csv"
  require "open-uri"

  known_vocabs = CSV.foreach(ConceptQL.vocabularies_file_path, headers: true, header_converters: :symbol).each_with_object({}) do |row, h|
    h[row[:id].downcase] = row.to_hash
  end

  amgen_vocabs = open(args.csv_path) do |amgen_csv_file|
    CSV.parse(amgen_csv_file.read, headers: true, header_converters: :symbol).each_with_object({}) do |row, h|
      h[row[:vocabulary_short_name].downcase] = row.to_hash
    end
  end

  new_from_amgen = amgen_vocabs.keys - known_vocabs.keys
  new_vocabs = new_from_amgen.each_with_object({}) do |key, h|
    amgen_vocab = amgen_vocabs[key]
    new_vocab = {
      id: amgen_vocab[:vocabulary_short_name],
      omopv4_vocabulary_id: amgen_vocab[:vocabulary_id],
      vocabulary_full_name: amgen_vocab[:vocabulary_long_name],
      vocabulary_short_name: amgen_vocab[:vocabulary_short_name],
      domain: amgen_vocab[:omop_table],
      hidden: nil,
      format_regexp: nil
    }
    h[new_vocab[:id]] = new_vocab
  end

  headers = new_vocabs.first.last.keys
  CSV.open(ConceptQL.custom_vocabularies_file_path, "w") do |csv|
    csv << headers
    new_vocabs.sort_by { |k, v| v[:id] }.map { |k, v| v.values_at(*headers) }.each do |row|
      csv << row
    end
  end
end

desc "Dump a set of diagnostics"
task :diagnostics do
  require "sequelizer"
  require "pp"
  puts "*" * 80
  puts "Free Space"
  pp `df -h`
  puts "*" * 80
  puts "Environment"
  pp ENV
  puts "*" * 80
  puts "Sequelizer"
  system("bundle exec sequelizer config")
  puts "*" * 80
  puts "Database"
  include Sequelizer
  pp db
  pp db.tables
end
