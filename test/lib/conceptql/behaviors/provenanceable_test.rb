require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Provenanceable do
  it "should find the config directory" do
    class TestClass
      include ConceptQL::Provenanceable
    end
    TestClass.new.provenance_yaml_file.exist?.must_equal(true)
  end
end
