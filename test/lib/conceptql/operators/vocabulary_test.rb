require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::Vocabulary do
  it "should populate known vocabularies from file" do
    ConceptQL::Operators::Vocabulary.to_metadata(:name)[:options][:vocabulary][:options].wont_be_empty
  end
end
