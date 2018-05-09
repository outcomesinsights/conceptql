
describe ConceptQL::DataModel::Gdm do
  describe "#related_concept_ids" do
    let(:dm) do
      ConceptQL::DataModel::Gdm.new(nil, nil)
    end

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

