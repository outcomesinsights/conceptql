# frozen_string_literal: true

require_relative '../../db_helper'

# The display-name joins read a cut-down concept table when the Database has
# one (bead conceptql-auu, seed conceptql-8u6).
describe 'ConceptQL::Database name_concepts_table' do
  name_joins = %w[dose_con ing_con unit_con concept_con asc dlc]
  # A drug and two lab results in the test data that have concept names.
  statement = ['union', %w[ndc 60429015703], %w[loinc 4548-4 72166-2], ['hospitalization']]
  table = :conceptql_test_name_concepts

  def mock_cdb(data_model, opts = {})
    ConceptQL::Database.new(Sequel.mock(host: :postgres), opts.merge(data_model: data_model))
  end

  %i[gdm gdm_wide].each do |data_model|
    it "points every name join at the table in #{data_model}" do
      sql = mock_cdb(data_model, name_concepts_table: :name_refs).query(statement).sql

      _(sql.scan(/AS "(#{name_joins.join("|")})"/).flatten.uniq.sort).must_equal name_joins.sort
      _(sql).wont_match(/FROM "concepts?"/)
      _(sql).must_include '"name_refs"'
    end

    it "keeps the full concept table without the option in #{data_model}" do
      sql = mock_cdb(data_model).query(statement).sql

      _(sql).wont_include '"name_refs"'
    end
  end

  it 'refuses to build a table it has no name for' do
    _ { mock_cdb(:gdm_wide).create_name_concepts_table }.must_raise ArgumentError
  end

  describe 'on the test data' do
    before do
      skip 'not tried on Spark' if DB.database_type.to_sym == :spark
      DB.drop_table?(table)
    end

    after do
      DB.drop_table?(table)
    end

    def rows(cdb, statement)
      cdb.query(statement).query.all.sort_by(&:to_s)
    end

    it 'returns the same rows as the full concept table' do
      cdb = ConceptQL::Database.new(DB, data_model: CDB.opts[:data_model], name_concepts_table: table)
      cdb.create_name_concepts_table

      expected = rows(CDB, statement)
      actual = rows(cdb, statement)

      _(actual).must_equal expected
      # The rows carry names, so the comparison covers the drug and lab joins.
      %i[drug_name unit_concept value_as_concept].each do |column|
        _(expected.map { |row| row[column] }.compact).wont_be_empty
      end
      _(DB[table].count).must_be :<, CDB.lexicon.concepts_table(DB).count
    end
  end
end
