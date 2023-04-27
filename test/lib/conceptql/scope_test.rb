require_relative "../../helper"


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
        check_sequel(db.query(["ADMSRCE", "12"], opts), :scope, :postgres_date_range_under_gdm)
      end

      it "should limit selection by date range under omopv4_plus for source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["icd9", "412"], opts), :scope, :postgres_date_range_under_omopv4_plus_source_vocab)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :scope, :postgres_date_range_under_gdm_source_vocab)
      end

      it "should limit selection by date range under omopv4_plus for standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["cpt", "99214"], opts), :scope, :postgres_date_range_under_omopv4_plus_standard_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :scope, :postgres_date_range_under_gdm_standard_vocab)
      end
    end

    describe "with windows from another table" do
      let(:opts) do
        { scope_opts: { window_table: :jtemp } }
      end

      it "should limit selection by date range under gdm" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["ADMSRCE", "12"], opts), :scope, :postgres_window_table_under_gdm)
      end

      it "should limit selection by date range under omopv4_plus for source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["icd9", "412"], opts), :scope, :postgres_window_table_under_omopv4_plus_source_vocab)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :scope, :postgres_window_table_under_gdm_source_vocab)
      end

      it "should limit selection by date range under omopv4_plus for standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["cpt", "99214"], opts), :scope, :postgres_window_table_under_omopv4_plus_standard_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :scope, :postgres_window_table_under_gdm_standard_vocab)
      end

      it "should not limit selection on person table" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        _(db.query(["person", true], opts).sql).wont_match(/EXISTS/)
      end

      it "should limit selection on condition_occurrence table" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        _(db.query(["icd9", "412"], opts).sql).must_match(/inner join/i)
      end

      it "should not apply to inner query of revenue code operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        _(db.query(["revenue_code", "0450"], opts).sql.downcase.scan(/inner join/i).count).must_equal 1
      end

      it "should have revenue code search revenue_code_source_value" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        _(db.query(["revenue_code", "0450"], opts).sql.downcase).must_match(/revenue_code_source_value/i)
      end

      it "should not apply to inner query of drg operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        _(db.query(["drg", "829"], opts).sql.downcase.scan(/inner join/i).count).must_equal 1
      end

      it "should have drg code search disease_class_source_value" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        _(db.query(["drg", "829"], opts).sql.downcase).must_match(/disease_class_source_value/i)
      end
    end

    describe "with windows from another table, along with adjustments" do
      let(:opts) do
        { scope_opts: { window_table: :jtemp, adjust_window_start:  "-30d", adjust_window_end: "1m"} }
      end

      it "should limit selection by date range under gdm" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["ADMSRCE", "12"], opts), :scope, :postgres_window_table_with_adjustments_under_gdm)
      end

      it "should limit selection by date range under omopv4_plus for source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["icd9", "412"], opts), :scope, :postgres_window_table_with_adjustments_under_omopv4_plus_source_vocab)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :scope, :postgres_window_table_with_adjustments_under_gdm_source_vocab)
      end

      it "should limit selection by date range under omopv4_plus for standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["cpt", "99214"], opts), :scope, :postgres_window_table_with_adjustments_under_omopv4_plus_standard_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :scope, :postgres_window_table_with_adjustments_under_gdm_standard_vocab)
      end
    end
  end
end
