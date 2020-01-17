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
          db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm, force_temp_tables: true, scratch_database: "jigsaw_temp")
          _(db.query(["ADMSRCE", "12", {label: "test label"}], opts).sql).must_match /jtemp123456/
        end
      end
    end

    describe "with date literal windows" do
      let(:opts) do
        { scope_opts: { start_date: "2001-01-01", end_date: "2001-12-31" } }
      end

      it "should limit selection by date range under gdm" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["ADMSRCE", "12"], opts), :postgres_date_range_under_gdm)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :postgres_date_range_under_gdm_source_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :postgres_date_range_under_gdm_standard_vocab)
      end
    end

    describe "with windows from another table" do
      let(:opts) do
        { scope_opts: { window_table: :jtemp } }
      end

      it "should limit selection by date range under gdm" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["ADMSRCE", "12"], opts), :postgres_window_table_under_gdm)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :postgres_window_table_under_gdm_source_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :postgres_window_table_under_gdm_standard_vocab)
      end
    end

    describe "with windows from another table, along with adjustments" do
      let(:opts) do
        { scope_opts: { window_table: :jtemp, adjust_window_start:  "-30d", adjust_window_end: "1m"} }
      end

      it "should limit selection by date range under gdm" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["ADMSRCE", "12"], opts), :postgres_window_table_with_adjustments_under_gdm)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :postgres_window_table_with_adjustments_under_gdm_source_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :postgres_window_table_with_adjustments_under_gdm_standard_vocab)
      end
    end
  end
end
