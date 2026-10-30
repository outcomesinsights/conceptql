# frozen_string_literal: true

require_relative "../../../db_helper"

# Every stream is a set (seed conceptql-0eb, bead conceptql-1jy). With
# compare_all, each left row joins every right row of the person, and two
# right rows can trim it to the same date. That row comes out once.
describe "trim_date_start and trim_date_end with compare_all" do
  def counts(statement)
    ds = CDB.query(statement).query.from_self
    [ ds.count, ds.distinct.from_self.count ]
  end

  mi = [ "icd9", "412" ]
  codes = %w[icd9 355.8 401.0 401.9 250.00 780.93 459.81]

  %w[trim_date_end trim_date_start].each do |operator|
    {
      "the same left and right" => { left: mi, right: mi, compare_all: true },
      "different left and right" => { left: codes, right: mi, compare_all: true },
      "within" => { left: codes, right: codes, compare_all: true, within: "30d" }
    }.each do |name, options|
      it "#{operator} returns each row once with #{name}" do
        total, distinct = counts([ operator, options ])

        _(distinct).must_be :>, 0
        _(total).must_equal distinct
      end
    end
  end
end
