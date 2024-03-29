begin
  require "bundler/gem_tasks"
rescue LoadError
end

ENV['CONCEPTQL_DATA_MODEL'] ||= ConceptQL::DEFAULT_DATA_MODEL.to_s

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

desc "Show which columns can be ignored"
task :ignorables, [:data_model] do |t, args|
  require 'conceptql'
  dm = args[:data_model].to_sym
  ignorables = ConceptQL::DataModel.get(dm).schema.each_with_object([]) do |(table, table_info), iggies|
    if table_info[:ignorable]
      iggies << [table.to_s, "all columns"]
      next
    else
      table_info[:columns].map do |column_name, column_info|
        if column_info[:ignorable]
          iggies << [table.to_s, column_name.to_s]
        end
      end
    end
  end

  additional = Pathname.new("schemas") + "#{dm}_more_ignorables.tsv"
  if additional.exist?
    ignorables += CSV.readlines(additional, col_sep: "\t")
  end

  puts ignorables.sort.map{ |arr| arr.join("\t") }.join("\n")
end

desc "Drop all tables/columns which can be ignored"
task :drop_ignorables, [:data_model] do |t, args|
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
