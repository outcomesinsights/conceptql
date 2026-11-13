# frozen_string_literal: true

require_relative "../../../db_helper"

# co_reported keeps a source record (its context_id on GDM) only when every
# upstream has an event in it. The events of a record that lacks any one
# upstream are dropped from all streams (conceptql-5t0 documents this).
describe ConceptQL::Operators::CoReported do
  diabetes = [ "icd9", "250.00" ]
  office_visit = [ "cpt", "99214" ]

  # [criterion_table, criterion_id, context_id] for each event of a statement.
  def events_with_contexts(statement)
    rows = CDB.query(statement).query.select(:criterion_table, :criterion_id).all
    rows.group_by { |row| row[:criterion_table] }.flat_map do |table, table_rows|
      DB[table.to_sym]
        .where(id: table_rows.map { |row| row[:criterion_id] })
        .select_map(%i[id context_id])
        .map { |id, context_id| [ table, id, context_id ] }
    end
  end

  it "keeps only the records that every upstream has an event in" do
    skip "context_id exists only in GDM data models" unless %i[gdm gdm_wide].include?(CDB.opts[:data_model])

    upstreams = [ diabetes, office_visit ].map { |statement| events_with_contexts(statement) }
    shared = upstreams.map { |events| events.map(&:last).uniq }.inject(:&)
    expected = upstreams.flatten(1).select { |_, _, context_id| shared.include?(context_id) }

    actual = events_with_contexts([ "co_reported", diabetes, office_visit ])

    _(shared).wont_be_empty
    _(actual.sort).must_equal(expected.sort)
    # The fixture has records with only one of the two codes, and their events are gone.
    _(actual.size).must_be :<, upstreams.sum(&:size)
  end
end

# co_reported passes along the records of every upstream, so one person can
# get one row from each. On the DuckDB fixture, co_reported of two first
# operators gave 7 persons more than one row (bead conceptql-8q8h). No live
# database: the mock never answers a query.
describe "co_reported events_per_patient" do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide) }

  def events_per_patient(statement)
    cdb.query(statement).events_per_patient
  end

  it "is multiple with two first upstreams" do
    _(events_per_patient([ "co_reported", [ "first", %w[icd9 250.00] ], [ "first", %w[cpt 99214] ] ])).must_equal :multiple
  end

  it "is multiple with two vocabulary upstreams" do
    _(events_per_patient([ "co_reported", %w[icd9 250.00], %w[cpt 99214] ])).must_equal :multiple
  end

  it "is single with one first upstream" do
    _(events_per_patient([ "co_reported", [ "first", %w[icd9 250.00] ] ])).must_equal :single
  end
end
