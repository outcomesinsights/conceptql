# frozen_string_literal: true

require_relative "../../../db_helper"

# place_of_service_filter keeps the records whose place of service is one of
# its codes, from the CMS Place of Service vocabulary. A record's place of
# service is pos_concept_id: in gdm it is a column of the record's context
# (contexts, through context_id), and in gdm_wide a column of observations.
#
# The test data has no place of service: pos_concept_id is NULL in every row
# of both tables, on Postgres and on DuckDB. So each test that needs one sets
# it on the contexts (gdm) or observations (gdm_wide) of the ICD-9 412
# records, in a transaction that it rolls back. A third of those rows get
# code 21 (Inpatient Hospital), a third code 22 (Outpatient Hospital), and
# the rest keep NULL.
describe ConceptQL::Operators::PlaceOfServiceFilter do
  def upstream
    %w[icd9 412]
  end

  def statement(*codes)
    [ "place_of_service_filter", upstream, *codes ]
  end

  def records(*codes)
    CDB.query(statement(*codes)).query.select_map(:criterion_id).sort
  end

  def errors(*codes)
    CDB.query(statement(*codes)).annotate.last[:annotation][:errors]
  end

  def concept_id(code)
    ids = CDB.lexicon.concept_ids(DB, "CMS Place of Service", [ code ])
    _(ids.size).must_equal 1, "CMS Place of Service #{code} is not in the lexicon"
    ids.first
  end

  # The table that holds pos_concept_id, qualified with its schema. On DuckDB
  # the unqualified name is a view, which cannot be updated.
  def place_of_service_table
    table = CDB.opts[:data_model] == :gdm_wide ? :observations : :contexts
    schema = ENV.fetch("SEQUELIZER_SEARCH_PATH").split(",").map { |s| s.strip.to_sym }
                .find { |s| DB.table_exists?(Sequel[s][table]) }
    _(schema).wont_be_nil "no schema on the search path has #{table}"
    Sequel[schema][table]
  end

  # [record id, id of its row in place_of_service_table] for each ICD-9 412
  # record that has such a row.
  def upstream_rows
    ids = CDB.query(upstream).query.select_map(:criterion_id)
    return ids.map { |id| [ id, id ] } if CDB.opts[:data_model] == :gdm_wide

    DB[:clinical_codes].where(id: ids).exclude(context_id: nil).select_map(%i[id context_id])
  end

  # Sets the places of service and yields { code => its record ids }, with
  # nil for the records that keep NULL. Everything is rolled back.
  def with_places_of_service
    skip "Spark cannot update the test data" if DB.database_type.to_sym == :spark

    DB.transaction(rollback: :always) do
      rows = upstream_rows
      place_ids = rows.map(&:last).uniq.sort
      inpatient, outpatient, none = place_ids.each_slice((place_ids.size / 3.0).ceil).to_a
      table = place_of_service_table
      DB[table].where(id: inpatient).update(pos_concept_id: concept_id("21"))
      DB[table].where(id: outpatient).update(pos_concept_id: concept_id("22"))

      expected = { "21" => inpatient, "22" => outpatient, nil => none }.transform_values do |places|
        rows.select { |_, place| places.include?(place) }.map(&:first).sort
      end
      expected.each_value { |ids| _(ids).wont_be_empty }
      yield expected
    end
  end

  describe "with a real place of service" do
    it "keeps the records whose place of service is the code" do
      with_places_of_service do |expected|
        _(records("21")).must_equal expected["21"]
        _(records("22")).must_equal expected["22"]
      end
    end

    it "keeps the records of any of several codes" do
      with_places_of_service do |expected|
        _(records("21", "22")).must_equal (expected["21"] + expected["22"]).sort
      end
    end

    it "drops the records that have no place of service" do
      with_places_of_service do |expected|
        _(records("21", "22") & expected[nil]).must_be_empty
      end
    end

    it "keeps no record for a code that no record has" do
      with_places_of_service do
        _(records("11")).must_be_empty
      end
    end

    # count_person_with_co_reported writes the code as a number.
    it "takes a code written as a number" do
      with_places_of_service do |expected|
        _(records(21)).must_equal expected["21"]
      end
    end
  end

  # "*" keeps a record whose place of service is any concept of the CMS
  # Place of Service vocabulary, as provenance's "*" keeps any provenance
  # concept.
  describe 'with "*"' do
    it "keeps every record that has a place of service" do
      with_places_of_service do |expected|
        _(records("*")).must_equal (expected["21"] + expected["22"]).sort
      end
    end

    it "drops the records that have no place of service" do
      with_places_of_service do |expected|
        _(records("*") & expected[nil]).must_be_empty
      end
    end

    # Codes are ORed, so "*" with other codes is "*".
    it "keeps every record with a place of service when other codes are given" do
      with_places_of_service do |expected|
        _(records("21", "*", "11")).must_equal (expected["21"] + expected["22"]).sort
      end
    end

    # A record whose pos_concept_id is a concept of another vocabulary (here
    # ICD-9-CM 412) has no place of service.
    it "drops a record whose place of service is not a CMS Place of Service concept" do
      with_places_of_service do |expected|
        other = CDB.lexicon.concept_ids(DB, "ICD9CM", [ "412" ])
        _(other.size).must_equal 1, "ICD9CM 412 is not in the lexicon"
        places = upstream_rows.select { |id, _| expected[nil].include?(id) }.map(&:last)
        DB[place_of_service_table].where(id: places).update(pos_concept_id: other.first)

        _(records("*")).must_equal (expected["21"] + expected["22"]).sort
      end
    end
  end

  it "reads the place of service from pos_concept_id" do
    _(CDB.query(statement("21")).sql).must_match(/["`]pos_concept_id["`]/)
  end

  describe "with an unknown code" do
    let(:unknown) { ConceptQL::Operators::Operator::UNKNOWN_CODE }

    it "accepts the codes of the vocabulary" do
      _(errors("21", "22", 11, "99")).must_be_nil
    end

    it "reports a code that is not in the vocabulary" do
      _(errors("21", "98")).must_equal [ [ unknown, "98" ] ]
    end

    it "reports only the unknown codes, as written and in the order written" do
      _(errors("garbage", "21", 98, "Inpatient")).must_equal [ [ unknown, "garbage", 98, "Inpatient" ] ]
    end

    it 'accepts "*"' do
      _(errors("*")).must_be_nil
      _(errors("*", "21", 11)).must_be_nil
    end

    it 'reports an unknown code that is given with "*"' do
      _(errors("*", "98", "21")).must_equal [ [ unknown, "98" ] ]
    end

    # The form of Draft algorithm 7acf23d1 (stenting_femoral_artery_atherectomy)
    # in production: the code comes before the upstream.
    it 'validates "*" before the upstream' do
      _(CDB.query([ "place_of_service_filter", "*", [ "cpt_or_hcpcs", "37226" ] ]).validation_errors).must_be_empty
    end

    # The vocabulary has no vocabulary_formats row, so a code matches only in
    # its own case, as the lookup matches it (seed conceptql-oji ruling "b").
    # Every real code is a number, so a code with a letter is added here.
    it "reports a code in another case" do
      CDB.lexicon.stub(:concept_codes, ->(*) { %w[21 22 0A] }) do
        _(errors("0A", "21")).must_be_nil
        _(errors("0a", "21")).must_equal [ [ unknown, "0a" ] ]
      end
    end

    # The codes have two digits, so the number 1 is not the code 01 (Pharmacy).
    it "reports a one-digit number" do
      _(errors(1)).must_equal [ [ unknown, 1 ] ]
    end

    it "refuses an unknown code in the plain query" do
      error = _ { CDB.query(statement("98")).sql }.must_raise ConceptQL::InvalidStatementError
      _(error.errors.values).must_equal [ [ [ unknown, "98" ] ] ]
    end

    # With no lexicon there are no codes to check against.
    it "checks nothing without a database" do
      cdb = ConceptQL::Database.new(nil, data_model: :gdm)
      annotated = cdb.query(statement("98")).annotate(skip_counts: true)

      _(annotated.last[:annotation][:errors]).must_be_nil
    end
  end
end
