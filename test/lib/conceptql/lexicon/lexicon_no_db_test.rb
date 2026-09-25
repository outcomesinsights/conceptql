# frozen_string_literal: true

require_relative '../../../helper'

# LexiconNoDB is what a db-less ConceptQL::Database falls back to. It must
# answer the same table methods as LexiconGDM / LexiconOhdsi, because
# LexiconStrategy's lookups are written against them; before it did,
# provenance, gender, race, place_of_service_filter and lab/drug columns all
# raised NoMethodError db-less.
describe ConceptQL::LexiconNoDB do
  let(:lexicon) { ConceptQL::LexiconNoDB.new(Sequel.mock(host: :postgres)) }

  it 'names the GDM-layout vocabulary tables' do
    _(lexicon.concepts_table(nil).sql).must_equal 'SELECT * FROM "concepts"'
    _(lexicon.ancestors_table(nil).sql).must_equal 'SELECT * FROM "ancestors"'
    _(lexicon.is_a_relationships(nil).sql).must_equal(
      %(SELECT * FROM "mappings" WHERE (lower("relationship_id") = 'is_a'))
    )
  end

  it 'answers every base-class lookup with no rows instead of raising' do
    _(lexicon.concepts(nil, 'Provenance Type').select_map(:concept_code)).must_equal []
    _(lexicon.concept_ids(nil, 'Place of Service', ['21'])).must_equal []
    _(lexicon.concepts_by_name(nil, ['White']).select_map(:id)).must_equal []
    _(lexicon.descendants_of(nil, [])).must_equal []
    _(lexicon.related_concept_ids(nil, 8507)).must_equal [8507]
  end

  describe 'a db-less database' do
    let(:cdb) { ConceptQL::Database.new(nil, data_model: :gdm) }

    it 'falls back to this strategy' do
      _(cdb.lexicon.strategy).must_equal :no_db
    end

    it 'annotates provenance, which reads the lexicon while validating' do
      annotated = cdb.query(['provenance', 'inpatient', %w[icd9 250.00]]).annotate(skip_counts: true)

      _(annotated.first).must_equal 'provenance'
      _(annotated.last[:annotation][:counts].keys).must_equal [:condition_occurrence]
    end
  end
end
