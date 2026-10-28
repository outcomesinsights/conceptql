# frozen_string_literal: true

require_relative "../../db_helper"

# Query#sql(:formatted) formats inside the Ruby process with sequel-sqlformat
# (bead conceptql-1i0). Formatting must change only whitespace and keyword case.
describe ConceptQL::Query do
  # Removes whitespace outside quoted text and upcases everything outside quotes.
  # Quoted strings and identifiers stay exactly as they are, so a change inside
  # them still fails the comparison.
  def normalize(sql)
    sql.scan(/'(?:[^']|'')*'|"(?:[^"]|"")*"|`[^`]*`|[^\s'"`]+/)
       .map { |token| token.match?(/\A['"`]/) ? token : token.upcase }
       .join
  end

  def statement
    [ "first",
      [ "union",
        [ "icd9", "412", { label: "heart attack" } ],
        [ "cpt", "99214" ],
        [ "recall", "heart attack" ] ] ]
  end

  # The queries here come from CDB, so Query#format reads CDB's database type.
  def with_database_type(type, &block)
    CDB.stub(:database_type, type, &block)
  end

  describe "#sql(:formatted)" do
    it "changes only whitespace and keyword case for every database type" do
      %i[postgres duckdb spark].each do |type|
        query = CDB.query(statement)
        raw = query.sql_statements
        formatted = with_database_type(type) { query.sql_statements(:formatted) }

        _(formatted.keys).must_equal(raw.keys)
        raw.each do |name, sql|
          _(formatted[name]).must_include("\n")
          _(normalize(formatted[name])).must_equal(normalize(sql), "#{type} #{name}")
        end
      end
    end

    it "passes the dialect for the database type to sequel-sqlformat" do
      { postgres: :postgresql, duckdb: :generic, spark: :generic }.each do |type, dialect|
        query = CDB.query(statement)
        seen = []
        recorder = lambda do |sql, **opts|
          seen << opts
          sql
        end
        Sequel::SQLFormat.stub(:format, recorder) do
          with_database_type(type) { query.sql(:formatted) }
        end

        _(seen).wont_be_empty
        seen.each do |opts|
          _(opts).must_equal({ dialect: dialect, indent: 2, uppercase: true })
        end
      end
    end

    it "keeps DuckDB and Spark syntax that Postgres does not accept" do
      samples = {
        duckdb: "select person_id, start_date + interval 7 day as d from slim.patients where x is distinct from y",
        spark: "select `person_id`, datediff(`end_date`, `start_date`) from `wide`.`observations` " \
               "where (`a` <=> `b`) and `c` rlike '^4[0-9]{2}'"
      }
      samples.each do |type, sql|
        query = CDB.query(statement)
        formatted = with_database_type(type) { query.send(:format, sql) }

        _(formatted).must_include("\n")
        _(normalize(formatted)).must_equal(normalize(sql), type.to_s)
      end
    end
  end
end
