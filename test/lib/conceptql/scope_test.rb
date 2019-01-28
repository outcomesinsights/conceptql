require_relative "../../helper"

def check_sequel(query, name)
  file = Pathname.new("test") + "fixtures" + "scope" + "#{name}.txt"
  actual_sql = query.sql
  if !file.exist? || ENV["CONCEPTQL_OVERWRITE_TEST_RESULTS"]
    file.dirname.mkpath
    file.write(actual_sql)
  end
  actual_sql.must_equal file.read
end

describe ConceptQL::Scope do
  describe "using postgres" do

    let(:host) { :postgres }

    describe "with a table_prefix" do
      let(:opts) do
        { scope_opts: { table_prefix: "jtemp123456" } }
      end

      it "should use prefix in table name" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm, force_temp_tables: true, scratch_database: "jigsaw_temp")
        db.query(["ADMSRCE", "12", {label: "test label"}], opts).sql.must_match /jtemp123456/
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

      it "should limit selection by date range under omopv4_plus for source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["icd9", "412"], opts), :postgres_date_range_under_omopv4_plus_source_vocab)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :postgres_date_range_under_gdm_source_vocab)
      end

      it "should limit selection by date range under omopv4_plus for standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["cpt", "99214"], opts), :postgres_date_range_under_omopv4_plus_standard_vocab)
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

      it "should limit selection by date range under omopv4_plus for source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["icd9", "412"], opts), :postgres_window_table_under_omopv4_plus_source_vocab)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :postgres_window_table_under_gdm_source_vocab)
      end

      it "should limit selection by date range under omopv4_plus for standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["cpt", "99214"], opts), :postgres_window_table_under_omopv4_plus_standard_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :postgres_window_table_under_gdm_standard_vocab)
      end

      it "should not limit selection on person table" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        db.query(["person", true], opts).sql.wont_match(/EXISTS/)
      end

      it "should limit selection on condition_occurrence table" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        db.query(["visit_occurrence", true], opts).sql.must_match(/inner join/i)
      end

      it "should not apply to inner query of revenue code operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        db.query(["revenue_code", "0450"], opts).sql.downcase.scan(/inner join/i).count.must_equal 1
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

      it "should limit selection by date range under omopv4_plus for source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["icd9", "412"], opts), :postgres_window_table_with_adjustments_under_omopv4_plus_source_vocab)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :postgres_window_table_with_adjustments_under_gdm_source_vocab)
      end

      it "should limit selection by date range under omopv4_plus for standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["cpt", "99214"], opts), :postgres_window_table_with_adjustments_under_omopv4_plus_standard_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :postgres_window_table_with_adjustments_under_gdm_standard_vocab)
      end
    end
  end

  describe "using impala" do

    let(:host) { :impala }

    describe "with date literal windows" do
      let(:opts) do
        { scope_opts: { start_date: "2001-01-01", end_date: "2001-12-31" } }
      end

      it "should limit selection by date range under gdm" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["ADMSRCE", "12"], opts), :impala_date_range_under_gdm)
      end

      it "should limit selection by date range under omopv4_plus for source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["icd9", "412"], opts), :impala_date_range_under_omopv4_plus_source_vocab)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :impala_date_range_under_gdm_source_vocab)
      end

      it "should limit selection by date range under omopv4_plus for standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["cpt", "99214"], opts), :impala_date_range_under_omopv4_plus_standard_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :impala_date_range_under_gdm_standard_vocab)
      end
    end

    describe "with windows from another table" do
      let(:opts) do
        { scope_opts: { window_table: :jtemp } }
      end

      it "should limit selection by date range under gdm" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["ADMSRCE", "12"], opts), :impala_window_table_under_gdm)
      end

      it "should limit selection by date range under omopv4_plus for source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["icd9", "412"], opts), :impala_window_table_under_omopv4_plus_source_vocab)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :impala_window_table_under_gdm_source_vocab)
      end

      it "should limit selection by date range under omopv4_plus for standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["cpt", "99214"], opts), :impala_window_table_under_omopv4_plus_standard_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :impala_window_table_under_gdm_standard_vocab)
      end

      it "should limit selection on person table" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        db.query(["person", true], opts).sql.must_match(/JOIN/)
      end

      it "should limit selection on condition_occurrence table" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        db.query(["visit_occurrence", true], opts).sql.must_match(/JOIN/)
      end

      it "avoids infinite recursion when processing CTEs" do
        statement = [:any_overlap,
                     {:left=>
                      [:from,
                       Sequel[:jigsaw_temp][:jtemp1c4qd4w_baseline_windows],
                       {:query_cols=>
                        [:person_id,
                         :criterion_id,
                         :criterion_table,
                         :criterion_domain,
                         :start_date,
                         :end_date,
                         :source_value,
                         :source_vocabulary_id,
                         :uuid]}],
                         :right=>
                        ["after",
                         {"left"=>
                          ["one_in_two_out",
                           ["during",
                            {"left"=>["union", ["icd9", "198.5"], ["icd10", "C79.51"]],
                             "right"=>
                          ["date_range", {"start"=>"2015-01-01", "end"=>"2016-12-31"}]}],
                          {"inpatient_return_date"=>"Discharge Date",
                           "outpatient_minimum_gap"=>"1y",
                           "outpatient_event_to_return"=>"Initial Event",
                           "outpatient_maximum_gap"=>"2y"}],
                           "right"=>["time_window", ["person"], {"start"=>"+18y-1d", "end"=>""}]}]}]

        opts = {
          force_temp_tables: true,
          scratch_database: :scratch,
          scope_opts: {
            window_table: :baseline_windows
          }
        }

        q = ConceptQL::Database.new(Sequel.mock(host: :impala), opts).query(statement)

        begin
          result = Timeout::timeout(2) do
            q.sql_statements
          end
          pass
        rescue Timeout::Error
          flunk
        end
      end
    end

    describe "with windows from another table, along with adjustments" do
      let(:opts) do
        { scope_opts: { window_table: :jtemp, adjust_window_start:  "-30d", adjust_window_end: "1m"} }
      end

      it "should limit selection by date range under gdm" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["ADMSRCE", "12"], opts), :impala_window_table_with_adjustments_under_gdm)
      end

      it "should limit selection by date range under omopv4_plus for source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["icd9", "412"], opts), :impala_window_table_with_adjustments_under_omopv4_plus_source_vocab)
      end

      it "should limit selection by date range under gdm with old source vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["icd9", "412"], opts), :impala_window_table_with_adjustments_under_gdm_source_vocab)
      end

      it "should limit selection by date range under omopv4_plus for standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :omopv4_plus)
        check_sequel(db.query(["cpt", "99214"], opts), :impala_window_table_with_adjustments_under_omopv4_plus_standard_vocab)
      end

      it "should limit selection by date range under gdm with old standard vocab operator" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        check_sequel(db.query(["cpt", "99214"], opts), :impala_window_table_with_adjustments_under_gdm_standard_vocab)
      end
    end
  end
end
