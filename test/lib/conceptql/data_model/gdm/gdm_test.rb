require_relative "../../../../db_helper"

describe ConceptQL::DataModel::Gdm do
  let(:dm) do
    ConceptQL::DataModel::Gdm.new(rdbms: nil, lexicon: nil)
  end

  describe "#related_concept_ids" do
    let(:db) do
      Sequel.sqlite
    end

    it "should find concept IDs related to standard concept ids" do
      db.create_table(:mappings) do
        column :concept_1_id, :Bigint
        column :relationship_id, :text
        column :concept_2_id, :Bigint
      end
      db[:mappings].import([:concept_1_id, :relationship_id, :concept_2_id], [[111111111, "IS_A", 8532]])
      _(dm.related_concept_ids(db, 8532).sort).must_equal [8532, 111111111].sort
    end
  end
end

