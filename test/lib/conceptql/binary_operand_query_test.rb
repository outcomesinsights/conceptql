# frozen_string_literal: true

require_relative "../../helper"

# A binary operator (after, before, during, ...) builds its left operand only
# from an array, so a missing left, or one that is a string, is nil. The
# statement is invalid. Query#events_per_patient and
# Query#multiple_vocabularies then give the values of an operator with no
# upstream: :multiple, because it never claims one row per person, and false.
# t_shank calls events_per_patient for each export.
# No database: Database.new(nil) builds the operators of each statement.
describe "Query with a missing left operand" do
  let(:cdb) { ConceptQL::Database.new(nil, data_model: :gdm_wide) }

  def query(name)
    cdb.query(JSON.parse(File.read("./test/statements/after/#{name}.json")))
  end

  %w[anno_1 anno_2].each do |name|
    it "gives :multiple events per patient for #{name}" do
      _(query(name).events_per_patient).must_equal :multiple
    end

    it "gives no multiple vocabularies for #{name}" do
      _(query(name).multiple_vocabularies).must_equal false
    end
  end

  # A left that exists still gives its own value. first gives :single, not
  # the :multiple of a missing left.
  it "reads the left operand when right is missing" do
    q = cdb.query([ "after", { "left" => [ "first", [ "icd9", "412" ] ] } ])
    _(q.events_per_patient).must_equal :single
  end
end
