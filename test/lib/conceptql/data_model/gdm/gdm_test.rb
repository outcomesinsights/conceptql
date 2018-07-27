require_relative "../../../../db_helper"

describe ConceptQL::DataModel::Gdm do
  let(:dm) do
    ConceptQL::DataModel::Gdm.new(nil, nil)
  end

  describe "#concept_id" do
    it "should return correct column for clinical_codes" do
      dm.concept_id(:clinical_codes).must_equal :clinical_code_concept_id
    end
  end
  describe "#related_concept_ids" do
    let(:db) do
      Sequel.sqlite
    end

    it "should find concept IDs related to standard concept ids" do
      db.create_table(:mappings) do
        column :concept_id_1, :Bigint
        column :relationship_id, :text
        column :concept_id_2, :Bigint
      end
      db[:mappings].import([:concept_id_1, :relationship_id, :concept_id_2], [[111111111, "IS_A", 8532]])
      dm.related_concept_ids(db, 8532).sort.must_equal [8532, 111111111].sort
    end
  end
end

