# frozen_string_literal: true

require_relative "../../db_helper"

# The test fixtures' slim.etl_vocabulary_ids lists 7 vocabularies: ICD9CM,
# CPT4, NDC, HCPCS, ICD9Proc, DRG and LOINC. An operator of any other
# vocabulary warns that the data has no records of it, and its counts are
# null. An operator whose inputs all have null counts has null counts too
# (bead conceptql-d1bd). operators/no_records_in_data_test.rb tests the
# table's other shapes.
describe "the counts of a vocabulary that the data does not contain" do
  def null_counts = { rows: nil, n: nil }

  def annotation_of(node)
    node.last[:annotation]
  end

  def annotate(statement, cdb = CDB)
    cdb.query(statement).annotate
  end

  it "gives an absent vocabulary the warning and null counts, and a present one neither" do
    gemscript = annotation_of(annotate(%w[gemscript 00003007]))
    icd9 = annotation_of(annotate(%w[icd9 412]))

    _(gemscript[:warnings]).must_equal([ [ ConceptQL::Operators::Vocabulary::NO_RECORDS_IN_DATA ] ])
    _(gemscript[:counts]).must_equal({ drug_exposure: null_counts })
    _(icd9[:warnings]).must_be_nil
    _(icd9[:counts][:condition_occurrence][:rows]).must_be :>, 0
  end

  it "gives read the warning, because the fixtures have no Read data" do
    read = annotation_of(annotate(%w[read S108.00]))

    _(read[:warnings].first).must_equal([ ConceptQL::Operators::Vocabulary::NO_RECORDS_IN_DATA ])
    _(read[:counts]).must_equal({ condition_occurrence: null_counts })
  end

  it "gives cpt_or_hcpcs real counts and no warning" do
    cpt_or_hcpcs = annotation_of(annotate(%w[cpt_or_hcpcs 99214]))

    _(cpt_or_hcpcs[:warnings]).must_be_nil
    _(cpt_or_hcpcs[:counts][:procedure_occurrence][:rows]).must_be :>, 0
  end

  it "gives null counts to an operator whose inputs all have null counts" do
    union = annotate([ "union", %w[gemscript 00003007], %w[gemscript 00003008] ])

    _(annotation_of(union)[:counts]).must_equal({ drug_exposure: null_counts })
    _(annotation_of(union)[:warnings]).must_be_nil
    _(union[1..2].map { annotation_of(_1)[:counts] }).must_equal([ { drug_exposure: null_counts } ] * 2)
  end

  it "gives real counts to an operator with one input that has real counts" do
    union = annotate([ "union", %w[gemscript 00003007], %w[icd9 412] ])

    _(annotation_of(union)[:counts][:condition_occurrence][:rows]).must_be :>, 0
    _(annotation_of(union)[:counts][:drug_exposure]).must_equal({ rows: 0, n: 0 })
  end

  it "gives null counts through a labeled operator and its recall" do
    statement = [ "first", [ "union", [ "gemscript", "00003007", { label: "drugs" } ], %w[recall drugs] ] ]

    _(annotation_of(annotate(statement))[:counts]).must_equal({ drug_exposure: null_counts })
  end

  it "reads etl_vocabulary_ids once for a query, whatever its number of operators" do
    sqls = []
    recorder = Object.new
    %i[debug info warn error].each do |level|
      recorder.define_singleton_method(level) { |message| sqls << message }
    end
    statement = [ "union", %w[gemscript 00003007], %w[gemscript 00003008], %w[icd9 412], %w[cpt 99214], %w[read S108.00] ]
    begin
      DB.loggers << recorder
      CDB.query(statement).annotate
    ensure
      DB.loggers.delete(recorder)
    end

    _(sqls.grep(/SELECT\s+\S*vocabulary_id\S*\s+FROM\s+\S*etl_vocabulary_ids/i).length).must_equal(1)
  end

  it "keeps the counts as they were when the data has no etl_vocabulary_ids" do
    cdb = ConceptQL::Database.new(DB, data_model: CDB.opts[:data_model])
    cdb.define_singleton_method(:source_table_exists?) do |db, table|
      table != :etl_vocabulary_ids && super(db, table)
    end
    gemscript = annotation_of(annotate(%w[gemscript 00003007], cdb))

    _(gemscript[:warnings]).must_be_nil
    _(gemscript[:counts]).must_equal({ drug_exposure: { rows: 0, n: 0 } })
  end
end
