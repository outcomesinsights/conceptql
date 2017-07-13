require_relative "../../../helper"

describe ConceptQL::DataModel::Omopv4Plus do
  describe "#related_concept_ids" do
    let(:dm) do
      ConceptQL::DataModel::Omopv4Plus.new(nil, nil)
    end

    it "should return concept IDs exactly the same as those fed to it" do
      dm.related_concept_ids(nil, 8532).sort.must_equal [8532].sort
    end
  end
end

