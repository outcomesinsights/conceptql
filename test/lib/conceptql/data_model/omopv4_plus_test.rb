require_relative "../../../helper"
require_relative "../../../db_helper"

describe ConceptQL::DataModel::Omopv4Plus do
  describe "#related_concept_ids" do
    let(:dm) do
      ConceptQL::DataModel::Omopv4Plus.new(nil, nil)
    end

    it "should return concept IDs exactly the same as those fed to it" do
      dm.related_concept_ids(nil, 8532).sort.must_equal [8532].sort
    end

    it "should return a single line per code, even if there are multiple descriptions available" do
      dm.concepts_ds(DB, [4,5], "99214").to_a.must_equal [{:vocabulary_id=>4, :concept_code=>"99214", :concept_text=>"Level 4 outpatient visit for evaluation and management of established patient with problem of moderate to high severity, including detailed history and medical decision making of moderate complexity - typical time with patient and/or family 25 minutes"}]
    end

    it "should have no source_vocabulary_id for person" do
      dm.source_vocabulary_id(:person).must_be_nil
    end

    it "should have no source_vocabulary_id for death" do
      dm.source_vocabulary_id(:death).must_be_nil
    end
  end
end

