# frozen_string_literal: true

require_relative '../../../db_helper'
require 'securerandom'

# conceptql-evk: gdm_wide_it keeps one observations row per admission. Many rows
# of one admission tie on (is_primary, collection_id, clinical_code_concept_id),
# so the kept row, and the discharge_date taken from its end_date, changed from
# run to run. Ryan ruled (2026-10-16) that an admission without a discharge
# date is discharged on its latest end_date, and that observations.id ends the
# ORDER BY. The test builds its own observations table with the ties on purpose.
describe 'ConceptQL::Behaviors::Utilizable gdm_wide discharge_date' do
  let(:stub_lexicon) do
    Class.new do
      def concept_ids(*)
        [4001]
      end

      def descendants_of(_data_db, ids)
        Array(ids).flatten
      end

      def concepts_table(_)
        :evk_concepts
      end
    end.new
  end

  # Rows are inserted in an order that is not the id order. Every row of one
  # admission has the same is_primary, collection_id and concept.
  rows = [
    { id: 13, admission: 9001, source_value: 'C', end_date: '2020-01-20' },
    { id: 12, admission: 9001, source_value: 'B', end_date: '2020-01-03' },
    { id: 11, admission: 9001, source_value: 'A', end_date: '2020-01-02' },
    { id: 22, admission: 9002, source_value: 'E', end_date: '2020-02-15', admit_discharge_date: '2020-02-10' },
    { id: 21, admission: 9002, source_value: 'D', end_date: '2020-02-02', admit_discharge_date: '2020-02-10' },
  ]

  observation_columns = {
    id: :Bignum, patient_id: :Bignum, collection_id: :Bignum, admission_detail_id: :Bignum,
    clinical_code_concept_id: :Bignum, clinical_code_source_value: String, clinical_code_vocabulary_id: String,
    provenance_concept_id: :Bignum, source_type_concept_id: :Bignum,
    admit_source_concept_id: :Bignum, discharge_location_concept_id: :Bignum,
    start_date: Date, end_date: Date, collection_start_date: Date, collection_end_date: Date,
    admit_admission_date: Date, admit_discharge_date: Date
  }

  before do
    skip 'not tried on Spark' if DB.database_type.to_sym == :spark
  end

  # A database of its own, so the observations table here hides nothing and
  # dropping it can never touch the test data.
  def with_own_db
    case DB.database_type.to_sym
    when :duckdb
      db = Sequel.connect(adapter: :duckdb, database: ':memory:')
    when :postgres
      schema = :"conceptql_evk_#{SecureRandom.hex(4)}"
      DB.create_schema(schema)
      db = Sequel.connect(DB.opts.merge(max_connections: 1))
      db.run("SET search_path TO #{db.literal(schema)}")
    else
      raise "no database of its own on #{DB.database_type}"
    end
    yield db
  ensure
    db&.disconnect
    DB.drop_schema(schema, cascade: true) if schema
  end

  define_method(:with_observations) do |&block|
    with_own_db do |db|
      db.create_table(:observations) { observation_columns.each { |name, type| column name, type } }
      db.create_table(:evk_concepts) do
        Bignum :id
        String :concept_code
        String :concept_text
      end
      rows.each { |row| db[:observations].insert(observation(**row)) }
      block.call(db)
    end
  end

  def observation(id:, admission:, source_value:, end_date:, admit_discharge_date: nil)
    {
      id: id, patient_id: admission, collection_id: admission * 10, admission_detail_id: admission,
      clinical_code_concept_id: 2_617_246, clinical_code_source_value: source_value,
      clinical_code_vocabulary_id: 'HCPCS', provenance_concept_id: 4001, source_type_concept_id: 4001,
      start_date: Date.parse(end_date), end_date: Date.parse(end_date),
      collection_start_date: Date.parse('2020-01-01'), collection_end_date: Date.parse('2020-03-01'),
      admit_admission_date: Date.parse('2020-01-01'), admit_discharge_date: admit_discharge_date && Date.parse(admit_discharge_date)
    }
  end

  def hospitalizations(db)
    cdb = ConceptQL::Database.new(db, data_model: :gdm_wide, lexicon: stub_lexicon)
    cdb.query(['hospitalization']).query.all
       .to_h { |row| [row[:criterion_id], row.slice(:discharge_date, :length_of_stay, :source_value)] }
  end

  def date(value)
    Date.parse(value.to_s)
  end

  it 'discharges an admission without a discharge date on its latest end_date' do
    with_observations do |db|
      admission = hospitalizations(db).fetch(90_010)

      _(date(admission[:discharge_date])).must_equal Date.parse('2020-01-20')
      _(admission[:length_of_stay].to_i).must_equal 20
    end
  end

  it 'keeps the discharge date of an admission that has one' do
    with_observations do |db|
      admission = hospitalizations(db).fetch(90_020)

      _(date(admission[:discharge_date])).must_equal Date.parse('2020-02-10')
      _(admission[:length_of_stay].to_i).must_equal 41
    end
  end

  it 'keeps the tied row with the lowest observations id' do
    with_observations do |db|
      _(hospitalizations(db).transform_values { |row| row[:source_value] }).must_equal(90_010 => 'A', 90_020 => 'D')
    end
  end
end
