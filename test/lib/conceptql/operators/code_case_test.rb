# frozen_string_literal: true

require_relative "../../../db_helper"

# A code matches its concept code case-exactly, unless the vocabulary's
# vocabulary_formats row declares case-insensitivity with (?i:...). No row of
# the pinned table declares it (seed conceptql-oji ruling "b"). A code in the
# wrong case selects no rows and gets the format warning.
describe "the case of a code" do
  def format_warnings(statement)
    by_operator(CDB.query(statement).warnings)
       .fetch(statement.first, [])
       .select { |message, *| message == "improperly formatted code" }
  end

  def count(statement)
    CDB.query(statement).query.count
  end

  it "selects the records of a code in its own case" do
    _(count(%w[icd9 V58.61])).must_be :>, 0
    _(format_warnings(%w[icd9 V58.61])).must_be_empty
  end

  it "selects no records for a code in another case, and warns about its format" do
    _(count(%w[icd9 v58.61])).must_equal 0
    _(format_warnings(%w[icd9 v58.61])).must_equal [ [ "improperly formatted code", "v58.61" ] ]
  end

  it "warns about i16.5 and not about I16.5" do
    _(format_warnings(%w[icd10cm I16.5])).must_be_empty
    _(format_warnings(%w[icd10cm i16.5])).must_equal [ [ "improperly formatted code", "i16.5" ] ]
    _(count(%w[icd10cm i16.5])).must_equal 0
  end

  it "keeps a code in the right case beside one in the wrong case" do
    _(count(%w[icd9 V58.61 v58.61])).must_equal count(%w[icd9 V58.61])
  end
end
