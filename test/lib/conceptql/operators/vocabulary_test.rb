require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::Vocabulary do
  it "should populate known vocabularies from file" do
    ConceptQL::Operators.operators[:omopv4_plus]["ADMSRCE"].must_equal ConceptQL::Operators::Vocabulary
  end
end
