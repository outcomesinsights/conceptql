require "sequelizer"
require_relative "../../helper"

describe ConceptQL::Lexicon do
  include Sequelizer

  let(:lexicon) { ConceptQL::Lexicon.new(nil, new_db) }

  describe "#descendants_of" do
    def make_ancestor_row(lexicon, a_id, d_id)
      if lexicon.strategy == :gdm
        db.create_table?(:ancestors, temp: true) do
          Integer :ancestor_id
          Integer :descendant_id
        end
        db[:ancestors].insert([a_id, d_id])
      else
        db.create_table?(:concept_ancestor, temp: true) do
          Integer :ancestor_concept_id
          Integer :descendant_concept_id
        end
        db[:concept_ancestor].insert([a_id, d_id])
      end
    end

    def get_descendants_of(ids_or_ds)
      lexicon.descendants_of(ids_or_ds).sort
    end

    it "should find passed in concept_id and descendants of concept_id" do
      make_ancestor_row(lexicon, 1, 2)

      _(get_descendants_of(1)).must_equal([1, 2])
    end

    it "should find passed in concept_id even if no descendants" do
      make_ancestor_row(lexicon, 1, 2)

      _(get_descendants_of(3)).must_equal([3])
    end
  end
end
