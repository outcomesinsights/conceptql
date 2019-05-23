$: << "lib"

require 'thor'
require 'sequelizer'
require 'json'
require 'pp'
require 'csv'
require 'conceptql'
require_relative 'query'

module ConceptQL
  class CLI < Thor
    include Sequelizer

    class_option :adapter,
      aliases: :a,
      desc: 'adapter for database'
    class_option :host,
      aliases: :h,
      banner: 'localhost',
      desc: 'host for database'
    class_option :username,
      aliases: :u,
      desc: 'username for database'
    class_option :password,
      aliases: :P,
      desc: 'password for database'
    class_option :port,
      aliases: :p,
      type: :numeric,
      banner: '5432',
      desc: 'port for database'
    class_option :database,
      aliases: :d,
      desc: 'database for database'
    class_option :search_path,
      aliases: :s,
      desc: 'schema for database (PostgreSQL only)'

    desc 'run_statement statement_file', 'Reads the ConceptQL statement from the statement file and executes it against the DB'
    def run_statement(statement_file)
      q = cdb(options).query(criteria_from_file(statement_file))
      puts q.sql
      puts JSON.pretty_generate(q.statement)
      pp q.query.all
    end

    desc 'sql statement_file', 'Reads the ConceptQL statement from the statement file and prints the SQL out'
    def sql(statement_file)
      q = cdb(options).query(criteria_from_file(statement_file))
      puts q.sql(:formatted, :create_tables)
    end

    desc "annotate_statement", "Reads in a statement and annotates it"
    def annotate_statement(statement_file)
      q = ConceptQL::Query.new(cdb(options), criteria_from_file(statement_file))
      pp q.annotate
    end

    desc 'metadata', 'Generates the metadata.js file for the JAM'
    def metadata
      File.write('metadata.js', "$metadata = #{ConceptQL.metadata(warn: true).to_json};")
      File.write('metadata.json', ConceptQL.metadata.to_json)
      if system("which", "json_pp", out: File::NULL, err: File::NULL)
        system("cat metadata.json | json_pp", out: "metadata_pp.json")
      end
    end

    desc 'selection_operators', 'Generates a TSV of all the selection operators'
    def selection_operators
      require 'csv'
      CSV.open('selection_operators.tsv', 'w', col_sep: "\t") do |csv|
        csv << ["name"]
        ConceptQL.metadata[:operators].values.select { |v| v[:basic_type] == :selection }.map { |v| v[:preferred_name] }.each do |name|
          csv << [name]
        end
      end

      CSV.open('domains.tsv', 'w', col_sep: "\t") do |csv|
        csv << ["name"]
        ConceptQL::Operators::TABLE_COLUMNS.each do |domain, columns|
          next unless columns.include?(:person_id)
          next if domain.to_s =~ /era\Z/
          csv << [domain]
        end
      end
    end

    desc 'dumpit', 'Dumps out test data into CSVs'
    def dumpit(path)
      path = Pathname.new(path)
      path.mkpath unless path.exist?
      headers_path = path + 'headers'
      headers_path.mkpath unless headers_path.exist?
      db.tables.each do |table|
        puts "Dumping #{table}..."
        ds = db[table]
        rows = ds.select_map(ds.columns)
        CSV.open(path + "#{table}.csv", "wb") do |csv|
          rows.each { |row| csv << row }
        end
        CSV.open(headers_path + "#{table}.csv", "wb") do |csv|
          csv << ds.columns
        end
      end
    end

    private

    def criteria_from_file(file)
      case File.extname(file)
      when '.json'
        JSON.parse(File.read(file))
      else
        eval(File.read(file))
      end
    end

    def filtered(results)
      results.each { |r| r.delete_if { |k,v| v.nil? } }
    end

    def cdb(options)
      ConceptQL::Database.new(db(options))
    end
  end
end
