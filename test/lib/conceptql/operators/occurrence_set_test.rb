# frozen_string_literal: true

require_relative "../../../db_helper"

# Every stream is a set (seed conceptql-0eb, bead conceptql-i3n). With
# at_least, each earlier row of a person nominates one row as its nth, and
# several earlier rows can nominate the same row. That row comes out once.
describe "occurrence with at_least" do
  codes = %w[icd9 355.8 401.0 401.9 250.00 780.93 459.81]

  def counts(statement)
    ds = CDB.query(statement).query.from_self
    [ ds.count, ds.distinct.from_self.count ]
  end

  {
    "at_least" => [ "occurrence", 2, codes, { at_least: "30d" } ],
    "at_least from the end" => [ "occurrence", -4, codes, { at_least: "7d" } ],
    "at_least and within" => [ "occurrence", 3, codes, { at_least: "30d", within: "1y" } ],
    "at_least and group_by_date" => [ "occurrence", 4, codes, { at_least: "7d", group_by_date: true } ]
  }.each do |name, statement|
    it "returns each row once with #{name}" do
      total, distinct = counts(statement)

      _(distinct).must_be :>, 0
      _(total).must_equal distinct
    end
  end
end
