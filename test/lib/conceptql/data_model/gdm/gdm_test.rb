# frozen_string_literal: true

require_relative '../../../../db_helper'

describe ConceptQL::DataModel::Gdm do
  let(:cdb) { CDB }
  let(:dm) do
    @dm ||= ConceptQL::DataModel::Gdm.new(nil, ConceptQL::Nodifier.new(cdb))
  end
  let(:db) do
    Sequel.sqlite
  end

  describe '#descendants_of' do
    let(:lexicon) { ConceptQL::Lexicon.new(db, strategy: ConceptQL::LexiconGDM.new(db)) }
    let(:cdb) { ConceptQL::Database.new(db, lexicon: lexicon) }

    def get_descendants_of(ids_or_ds)
      dm.descendants_of(db, ids_or_ds).sort
    end

    describe 'using GDM vocab tables' do
      def make_ancestor_row(a_id, d_id)
        db.create_table?(:ancestors, temp: true) do
          Integer :ancestor_id
          Integer :descendant_id
        end
        db[:ancestors].insert([a_id, d_id])
      end

      it 'should find passed in concept_id and descendants of concept_id' do
        make_ancestor_row(1, 2)

        _(get_descendants_of(1)).must_equal([1, 2])
      end

      it 'should find passed in concept_id even if no descendants' do
        make_ancestor_row(1, 2)

        _(get_descendants_of(3)).must_equal([3])
      end
    end

    describe 'using OHDSI vocab tables' do
      let(:lexicon) { ConceptQL::Lexicon.new(db, strategy: ConceptQL::LexiconOhdsi.new(db)) }
      def make_ancestor_row(a_id, d_id)
        db.create_table?(:concept_ancestor, temp: true) do
          Integer :ancestor_concept_id
          Integer :descendant_concept_id
        end
        db[:concept_ancestor].insert([a_id, d_id])
      end

      it 'should find passed in concept_id and descendants of concept_id' do
        make_ancestor_row(1, 2)

        _(get_descendants_of(1)).must_equal([1, 2])
      end

      it 'should find passed in concept_id even if no descendants' do
        make_ancestor_row(1, 2)

        _(get_descendants_of(3)).must_equal([3])
      end
    end
  end

  describe '#concept_id' do
    it 'should return correct column for clinical_codes' do
      _(dm.concept_id(:clinical_codes)).must_equal :clinical_code_concept_id
    end
  end
  describe '#related_concept_ids' do
    let(:lexicon) { ConceptQL::Lexicon.new(db, strategy: ConceptQL::LexiconGDM.new(db)) }
    let(:cdb) { ConceptQL::Database.new(db, lexicon: lexicon) }

    it 'should find concept IDs related to standard concept ids' do
      db.create_table(:mappings) do
        column :concept_1_id, :Bigint
        column :relationship_id, :text
        column :concept_2_id, :Bigint
      end
      db[:mappings].import(%i[concept_1_id relationship_id concept_2_id], [[111_111_111, 'IS_A', 8532]])
      _(dm.related_concept_ids(db, 8532).sort).must_equal [8532, 111_111_111].sort
    end
  end
end
