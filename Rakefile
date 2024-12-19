# frozen_string_literal: true

begin
  require 'bundler/gem_tasks'
rescue LoadError
end

run_spec = lambda do |data_model|
  sh "CONCEPTQL_DATA_MODEL=#{data_model} #{FileUtils::RUBY} test/all.rb"
end

desc 'Run tests with omopv4_plus data model'
task :test_omopv4_plus do
  run_spec.call(:omopv4_plus)
end

desc 'Run tests with gdm data model'
task :test_gdm do
  run_spec.call(:gdm)
end

desc 'Run tests with omopv4 data model with coverage'
task :test_cov do
  ENV['COVERAGE'] = '1'
  run_spec.call(:omopv4_plus)
end

desc 'Run tests with omopv4 data model'
task default: :test_omopv4_plus

desc "Ingests client's CSV file for custom vocabularies"
task :make_vocabs_csv, [:csv_path] do |_t, args|
  require 'conceptql'
  require 'csv'
  require 'open-uri'

  known_vocabs = CSV.foreach(ConceptQL.vocabularies_file_path, headers: true,
                                                               header_converters: :symbol).each_with_object({}) do |row, h|
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
  CSV.open(ConceptQL.custom_vocabularies_file_path, 'w') do |csv|
    csv << headers
    new_vocabs.sort_by { |_k, v| v[:id] }.map { |_k, v| v.values_at(*headers) }.each do |row|
      csv << row
    end
  end
end

desc 'Show which columns can be ignored'
task :ignorables, [:data_model] do |_t, args|
  require 'conceptql'
  dm = args[:data_model].to_sym
  ignorables = ConceptQL::DataModel.get(dm).schema.each_with_object([]) do |(table, table_info), iggies|
    if table_info[:ignorable]
      iggies << [table.to_s, 'all columns']
      next
    else
      table_info[:columns].map do |column_name, column_info|
        iggies << [table.to_s, column_name.to_s] if column_info[:ignorable]
      end
    end
  end

  additional = Pathname.new('schemas') + "#{dm}_more_ignorables.tsv"
  ignorables += CSV.readlines(additional, col_sep: "\t") if additional.exist?

  puts ignorables.sort.map { |arr| arr.join("\t") }.join("\n")
end

desc 'Drop all tables/columns which can be ignored'
task :drop_ignorables, [:data_model] do |_t, args|
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

def cdb
  @cdb ||= ConceptQL::Database.new(db, database_type: :presto)
end

def convert(from_file, to_file)
  sql = [
    cdb.query(JSON.parse(File.read(from_file))).sql,
    ';'
  ].join
  # table_name = from_file.sub('test/statements', '').gsub('/', '_')
  # ctas = db.send(:create_view_as_sql, sql)
  File.write(to_file, sql)
rescue ConceptQL::Query::QueryError
  puts "#{from_file} puked"
end

def prestofy(sql)
  tables = %w[
    addresses
    admission_details
    clinical_codes
    collections
    concept
    contexts
    contexts_practitioners
    costs
    deaths
    drug_exposure_details
    facilities
    information_periods
    measurement_details
    observations
    patients
    payer_reimbursements
    practitioners
  ].join('|')
  tables_regexp = Regexp.new(%{"(#{tables})"})
  sql
    .gsub('AS text', 'AS VARCHAR')
    .gsub(/AS float/i, 'AS DOUBLE')
    .gsub(/make_interval\((\w+)s := (-?\d+)\)/, %q(interval '\2' \1))
    .gsub(tables_regexp, %q("synpuf_250_ohdsi_wide_\1"))
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
    task all: ['schemas/ohdsi_vocabs.yml']
  end
end

namespace :test_script do
  require 'rake/clean'

  ALL_SQL = 'build/sqls/all.sql'
  ALL_PRESTO_SQL = 'build/sqls/all.presto.sql'
  stmt_files = FileList.new('test/statements/**/*.json') do |fl|
    fl.exclude(/anno_/)
  end
  sql_files = stmt_files.sub('test/statements', 'build/sqls/postgres').sub('.json', '.sql')
  presto_sql_files = sql_files.sub('/postgres/', '/presto/')

  stmt_files.zip(sql_files).each do |stmt_file, sql_file|
    file sql_file => stmt_file do |t|
      mkdir_p sql_file.pathmap('%d')
      convert(t.source, t.name)
    end
  end

  presto_sql_files.zip(sql_files) do |presto_sql_file, sql_file|
    file presto_sql_file => sql_file do |_t|
      mkdir_p presto_sql_file.pathmap('%d')
      File.write(presto_sql_file, prestofy(File.read(sql_file)))
    end
  end

  file ALL_SQL => sql_files do |t|
    File.write(t.name, t.prerequisites.map { |p| ["-- #{p}", File.read(p)].join("\n") }.join("\n"))
  end

  file ALL_PRESTO_SQL => presto_sql_files do |t|
    File.write(t.name, t.prerequisites.map { |p| ["-- #{p}", File.read(p)].join("\n") }.join("\n"))
  end

  task default: ALL_PRESTO_SQL
  CLEAN.include(sql_files, ALL_SQL, ALL_PRESTO_SQL)
end

namespace :driftr_script do
  require_relative 'lib/conceptql'
  require_relative 'test/statement_tests'
  require 'json'

  DRIFTR_SCRIPT = '/tmp/synpuf250_driftr.json'
  task default: DRIFTR_SCRIPT
  file DRIFTR_SCRIPT do |t|
    connection_info = {
      adapter_name: 'presto',
      args: {
        host: 'presto.titan.jsaw.io',
        port: 80,
        catalog: 'hive',
        schema: 'default',
        user: 'whoever'
      }
    }
    tests_h = {}
    ConceptQL::StatementFileTest.all(cdb).each do |file_test|
      file_test.each_test do |results|
        unless results.pure_sql?
          puts "Skip #{results.message}"
          next
        end

        puts "Make #{results.message}"

        sql = results.prep.sql

        view_name = results.message.gsub(/\W+/, '_')
        tests_h[results.message] = {
          sql: [
            cdb.db.send(
              :create_view_sql,
              view_name.to_sym,
              prestofy(sql),
              replace: true
            )
          ],
          expectations: {
            view_name => {
              type: 'json',
              contents: JSON.parse(results.expected)
            }
          }
        }
      end
    end

    h = {
      connection_info: connection_info,
      tests: tests_h
    }

    File.write(t.name, JSON.pretty_generate(h))
  end
end
