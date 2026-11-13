# frozen_string_literal: true

require_relative "../../helper"

# Query#extract_metadata walks the operator tree. A binary operator (after,
# before, during, ...) builds its left and right operands only from an
# array, so a missing operand, or one that is a string, is nil. The
# statement is invalid, and the walk visits only the operands that exist.
# No database: Database.new(nil) builds the operators of each statement.
describe "Query#extract_metadata with a missing binary operand" do
  let(:cdb) { ConceptQL::Database.new(nil, data_model: :gdm_wide) }

  def metadata(name)
    cdb.query(JSON.parse(File.read("./test/statements/after/#{name}.json"))).extract_metadata
  end

  it "walks only the operator when left and right are strings" do
    _(metadata("anno_1")).must_equal({
      unique_operators: [ "after" ],
      operators_in_preorder: [ "after" ],
      codeset_only: false,
      num_selection_nodes: 0,
      max_depth: 1
    })
  end

  it "walks the right operand when left is missing" do
    _(metadata("anno_2")).must_equal({
      unique_operators: [ "after", "gender", "time_window" ],
      operators_in_preorder: [ "after", "time_window", "gender" ],
      codeset_only: false,
      num_selection_nodes: 1,
      max_depth: 3
    })
  end

  it "walks the left operand when right is missing" do
    _(metadata("anno_3")).must_equal({
      unique_operators: [ "after", "icd9" ],
      operators_in_preorder: [ "after", "icd9" ],
      codeset_only: false,
      num_selection_nodes: 1,
      max_depth: 2
    })
  end
end
