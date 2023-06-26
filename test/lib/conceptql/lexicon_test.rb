require "sequelizer"
require_relative "../../helper"

describe ConceptQL::Lexicon do
  include Sequelizer
  let(:ldb) { new_db }
  let(:ddb) { new_db }
  let(:lexicon) { ConceptQL::Lexicon.new(ldb, ddb) }

  describe "#descendants_of" do
    def make_ancestor_row(db, a_id, d_id)
      db.create_table?(:ancestors, temp: true) do
        Integer :ancestor_id
        Integer :descendant_id
      end
      db[:ancestors].insert([a_id, d_id])
    end

    def get_descendants_of(ids_or_ds)
      lexicon.descendants_of(ids_or_ds).select_map(:descendant_id).sort
    end

    def make_concept_row(db, id, vocab_id, code)
      db.create_table?(:concepts, temp: true) do
        Integer :id
        String :vocabulary_id
        String :concept_code
      end
      db[:concepts].insert([id, vocab_id, code])
    end

    def make_vocabulary_row(db, id)
      db.create_table?(:vocabularies, temp: true) do
        String :id
      end
      db[:vocabularies].insert([id])
    end

    it "should find passed in concept_id and descendants of concept_id" do
      make_ancestor_row(ldb, 1, 2)

      _(get_descendants_of([1])).must_equal([1, 2])
    end

    it "should find passed in concept_id even if no descendants" do
      make_ancestor_row(ldb, 1, 2)

      _(get_descendants_of([3])).must_equal([3])
    end

    it "should handle Sequel::Dataset as concepts to look for" do
      make_ancestor_row(ldb, 1, 2)
      make_vocabulary_row(ldb, "vocab")
      make_concept_row(ldb, 1, "vocab", "EXAMPLE")

      ds = lexicon.concepts("vocab", "example").select(:id)

      _(get_descendants_of(ds)).must_equal([1, 2])
    end
  end
end
