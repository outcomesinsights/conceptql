# frozen_string_literal: true

require_relative "../../../db_helper"

# hospitalization, hospice and snf select the collections whose file
# provenance descends from their collection_type. The lexicon compares
# codes case-exactly (seed conceptql-oji ruling "b"), so collection_type
# must be the concept code as written. "SNF" found the concept "snf" only
# while the lookup ignored case. The test data has no SNF or hospice stays,
# so their results are empty either way, and only the lookup shows the error.
describe "the collection_type of a utilization operator" do
  %w[hospitalization hospice snf].each do |name|
    it "names a file provenance concept for #{name}" do
      operator = CDB.query([ name ]).operator
      dm = operator.dm

      _(dm.concept_codes(DB, dm.file_provenance_types_vocab)).must_include operator.collection_type
      _(dm.concept_ids(DB, dm.file_provenance_types_vocab, operator.collection_type)).wont_be_empty
    end
  end
end
