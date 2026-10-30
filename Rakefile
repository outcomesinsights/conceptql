# frozen_string_literal: true

begin
  require 'bundler/gem_tasks'
rescue LoadError
  # Optional: the gem release tasks are not needed by the test tasks below.
end

run_spec = lambda do |data_model|
  sh "CONCEPTQL_DATA_MODEL=#{data_model} #{FileUtils::RUBY} test/all.rb"
end

begin
  require 'rubocop/rake_task'

  RuboCop::RakeTask.new(:lint) do |task|
    task.options = [ '--display-cop-names' ]
  end

  RuboCop::RakeTask.new(:format) do |task|
    task.options = [ '--auto-correct-all' ]
  end

  desc 'Run RuboCop with safe autocorrect'
  task :lint_fix do
    system('bundle exec rubocop --autocorrect')
  end
rescue LoadError
  # RuboCop not available
end

# Runs the suite exactly as CI does: test/all.rb, with CONCEPTQL_DATA_MODEL,
# SEQUELIZER_URL and SEQUELIZER_SEARCH_PATH taken from the environment, never
# set here. The suite needs a live database (Postgres test_data, or the DuckDB
# fixture), so this is not self-contained.
desc 'Run the test suite against the database in SEQUELIZER_URL (data model from CONCEPTQL_DATA_MODEL)'
task :test do
  ruby 'test/all.rb'
end

desc 'Run tests with gdm data model'
task :test_gdm do
  run_spec.call(:gdm)
end

desc 'Run the test suite (same as rake test)'
task default: :test

desc "Ingests client's CSV file for custom vocabularies"
task :make_vocabs_csv, [ :csv_path ] do |_t, args|
  require 'conceptql'
  require 'csv'
  require 'open-uri'

  known_vocabs = CSV.foreach(ConceptQL.vocabularies_file_path, headers: true,
                                                               header_converters: :symbol).to_h do |row|
    [ row[:id].downcase, row.to_hash ]
  end

  amgen_vocabs = open(args.csv_path) do |amgen_csv_file|
    CSV.parse(amgen_csv_file.read, headers: true, header_converters: :symbol).to_h do |row|
      [ row[:vocabulary_short_name].downcase, row.to_hash ]
    end
  end

  new_from_amgen = amgen_vocabs.keys - known_vocabs.keys
  new_vocabs = new_from_amgen.each_with_object({}) do |key, h|
    amgen_vocab = amgen_vocabs[key]
    new_vocab = {
      id: amgen_vocab[:vocabulary_short_name],
      vocabulary_full_name: amgen_vocab[:vocabulary_long_name],
      vocabulary_short_name: amgen_vocab[:vocabulary_short_name],
      domain: amgen_vocab[:omop_table],
      hidden: nil,
      format_regexp: nil
    }
    h[new_vocab[:id]] = new_vocab
  end

  headers = new_vocabs.first.last.keys
  CSV.open(ConceptQL.custom_vocabularies_file_path, 'w') do |csv|
    csv << headers
    new_vocabs.sort_by { |_k, v| v[:id] }.map { |_k, v| v.values_at(*headers) }.each do |row|
      csv << row
    end
  end
end

desc 'Show which columns can be ignored'
task :ignorables, [ :data_model ] do |_t, args|
  require 'conceptql'
  dm = args[:data_model].to_sym
  ignorables = ConceptQL::DataModel.get(dm).schema.each_with_object([]) do |(table, table_info), iggies|
    if table_info[:ignorable]
      iggies << [ table.to_s, 'all columns' ]
      next
    else
      table_info[:columns].map do |column_name, column_info|
        iggies << [ table.to_s, column_name.to_s ] if column_info[:ignorable]
      end
    end
  end

  additional = Pathname.new('schemas') + "#{dm}_more_ignorables.tsv"
  ignorables += CSV.readlines(additional, col_sep: "\t") if additional.exist?

  puts ignorables.sort.map { |arr| arr.join("\t") }.join("\n")
end

desc 'Drop all tables/columns which can be ignored'
task :drop_ignorables, [ :data_model ] do |_t, args|
  require 'conceptql'
  require 'sequelizer'
  include Sequelizer
  dm = args[:data_model].to_sym

  db.set(search_path: "#{dm}_250")
  ConceptQL::DataModel.get(dm).schema.each do |table, table_info|
    if table_info[:ignorable]
      puts "#{table}\tall_columns"
      db.drop_table(table, if_exists: true)
      next
    end
    table_info[:columns].each do |column_name, column_info|
      if column_info[:ignorable]
        puts "#{table}\t#{column_name}"
        db.drop_column(table, column_name)
      end
    end
  end
end

desc 'Dump a set of diagnostics'
task :diagnostics do
  require 'sequelizer'
  puts '*' * 80
  puts 'Free Space'
  pp `df -h`
  puts '*' * 80
  puts 'Environment'
  pp ENV
  puts '*' * 80
  puts 'Sequelizer'
  system('bundle exec sequelizer config')
  puts '*' * 80
  puts 'Database'
  include Sequelizer
  pp db
  pp db.tables
end

Rake.application.options.trace_rules = true

namespace :schemas do
  require 'sequelizer'
  require_relative 'lib/conceptql/utils'
  include Sequelizer
  namespace :dump do
    file 'schemas/gdm_wide.yml' do |t|
      File.write(t.name, ConceptQL::Utils.schema_dump(db(search_path: 'slim,wide,ohdsi_vocabs,gdm_vocabs')))
    end
    file 'schemas/gdm.yml' do |t|
      File.write(t.name, ConceptQL::Utils.schema_dump(db(search_path: 'slim,ohdsi_vocabs,gdm_vocabs')))
    end
    file 'schemas/ohdsi_vocabs.yml' do |t|
      File.write(t.name, ConceptQL::Utils.schema_dump(db(search_path: 'ohdsi_vocabs')))
    end
    # task all: ['schemas/gdm.yml', 'schemas/gdm_wide.yml']
    task all: [ 'schemas/ohdsi_vocabs.yml' ]
  end
end
