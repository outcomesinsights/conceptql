require_relative "../../helper"

def check_sequel(query, name)
  file = Pathname.new("test") + "fixtures" + "scope" + "#{name}.txt"
  actual_sql = query.sql
  if !file.exist? || ENV["CONCEPTQL_OVERWRITE_TEST_RESULTS"]
    file.dirname.mkpath
    file.write(actual_sql)
  end
  _(actual_sql).must_equal(file.read)
end

describe ConceptQL::Scope do
  describe "using postgres" do

    let(:host) { :postgres }

    describe "with a table_prefix" do
      let(:opts) do
        { scope_opts: { table_prefix: "jtemp123456" } }
      end

      it "should use prefix in table name" do
        if ENV["CONCEPTQL_AVOID_CTES"] == "true"
          skip
        else
          cdb = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm, force_temp_tables: true, scratch_database: "jigsaw_temp")
          sql_matches(cdb.query(["ADMSRCE", "12", {label: "test label"}], opts).sql, "jtemp123456")
        end
      end
    end

    describe "with date literal windows" do
      let(:opts) do
        { scope_opts: { start_date: "2001-01-01", end_date: "2001-12-31" } }
      end

      it "should limit selection by date range under gdm" do
        cdb = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        sql_matches(cdb.query(["ADMSRCE", "12"], opts).sql, "CAST('2001-12-31' AS date)", "CAST('2001-01-01' AS date)")
      end
    end

    describe "with windows from another table" do
      let(:opts) do
        { scope_opts: { window_table: :jtemp } }
      end

      it "should limit selection by date range under gdm" do
        cdb = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        sql_matches(cdb.query(["ADMSRCE", "12"], opts).sql, "INNER JOIN", '"r"."start_date" <=')
      end
    end

    describe "with windows from another table, along with adjustments" do
      let(:opts) do
        { scope_opts: { window_table: :jtemp, adjust_window_start:  "-30d", adjust_window_end: "1m"} }
      end

      it "should limit selection by date range under gdm" do
        cdb = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        sql_matches(cdb.query(["ADMSRCE", "12"], opts).sql, "INNER JOIN", '"r"."start_date" AS timestamp', "1 months ' AS interval")
      end
    end
  end
end
