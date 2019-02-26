require_relative "../../helper"

describe ConceptQL::Lexicon do
  let(:ldb) { Sequel.connect("sqlite:/") }
  let(:ddb) { Sequel.connect("sqlite:/") }
  let(:lexicon) { ConceptQL::Lexicon.new(ldb, ddb) }

  describe "#descendants_of" do
    def make_ancestor_row(db, a_id, d_id)
      db.create_table?(:ancestors) do
        Integer :ancestor_id
        Integer :descendant_id
      end
      db[:ancestors].insert([a_id, d_id])
    end

    def get_descendants_of(ids_or_ds)
      lexicon.descendants_of(ids_or_ds).select_map(:descendant_id)
    end

    def make_concept_row(db, id, name)
      db.create_table?(:concepts) do
        Integer :id
        Integer :concept_code
      end
      db[:concepts].insert([id, name])
    end

    it "should find passed in concept_id and descendants of concept_id" do
      make_ancestor_row(ldb, 1, 2)

      get_descendants_of(1).must_equal([1, 2])
    end

    it "should find passed in concept_id even if no descendants" do
      make_ancestor_row(ldb, 1, 2)

      get_descendants_of(3).must_equal([3])
    end

    it "should handle Sequel::Dataset as concepts to look for" do
      make_ancestor_row(ldb, 1, 2)
      make_concept_row(ldb, 1, "example")
      ds = ldb[:concepts].where(concept_code: "example").select(:id)

      get_descendants_of(ds).must_equal([1, 2])
    end
  end
end
