# frozen_string_literal: true

require_relative "../../../db_helper"

# numeric accepts a column name in any case, so the statement must also run
# in any case on every engine. Postgres folds only unquoted names, and the
# SQL quotes the name, so the SQL spells the column as the rows do (bead
# conceptql-4bd).
describe "numeric with a column name in another case" do
  def values(statement)
    CDB.query(statement).query.order(:person_id, :criterion_id).select_map(:value_as_number)
  end

  it "reads the person table's column" do
    expected = values([ "numeric", "gender_concept_id" ])

    _(expected).wont_be_empty
    _(values([ "numeric", "Gender_Concept_ID" ])).must_equal expected
  end

  it "reads the upstream rows' column" do
    expected = values([ "numeric", "criterion_id", [ "icd9", "412" ] ])

    _(expected).wont_be_empty
    _(values([ "numeric", "Criterion_ID", [ "icd9", "412" ] ])).must_equal expected
  end
end
