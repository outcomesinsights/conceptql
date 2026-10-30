# frozen_string_literal: true

require_relative "../../../db_helper"

# Every stream is a set (seed conceptql-0eb, bead conceptql-3pr). With
# inner_join or include_rhs_columns, a temporal operator joins each left row
# to every matching right row. A left row comes out once, and with
# include_rhs_columns once for each different set of right columns.
describe "inner_join and include_rhs_columns" do
  def counts(statement)
    ds = CDB.query(statement).query.from_self
    [ ds.count, ds.distinct.from_self.count ]
  end

  {
    "during with include_rhs_columns" =>
      [ "during", { left: %w[icd9 412], right: [ "information_periods" ], include_rhs_columns: [ "criterion_domain" ] } ],
    "contains with inner_join" =>
      [ "contains", { left: [ "information_periods" ], right: [ "icd9", "729.5" ], inner_join: true } ],
    "any_overlap with inner_join" =>
      [ "any_overlap", { left: %w[icd9 412], right: %w[icd9 412], inner_join: true } ]
  }.each do |name, statement|
    it "returns each row once for #{name}" do
      total, distinct = counts(statement)

      _(distinct).must_be :>, 0
      _(total).must_equal distinct
    end
  end

  # The rows differ by the right side's uuid, so a left row comes out once for
  # each right row it contains. t_shank reads the rows this way.
  it "keeps the rows that differ by an include_rhs_columns column" do
    statement = [ "contains", { left: [ "information_periods" ], right: [ "icd9", "729.5", { uuid: true } ], include_rhs_columns: [ "uuid" ] } ]
    total, distinct = counts(statement)
    lefts = CDB.query(statement).query.from_self.select(:criterion_id).distinct.from_self.count

    _(total).must_equal distinct
    _(distinct).must_be :>, lefts
  end
end
