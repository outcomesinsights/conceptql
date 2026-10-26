# frozen_string_literal: true

require_relative "../../helper"

describe ConceptQL::Columnizer do
  let(:ds) { Sequel.mock(host: :postgres).from(:t) }

  def select_sql(*columns)
    columnizer = ConceptQL::Columnizer.new
    columnizer.add_columns(*columns)
    columnizer.apply(ds).sql
  end

  it "selects each column under its own name" do
    _(select_sql(:person_id, :end_date)).must_equal(
      'SELECT "person_id" AS "person_id", "end_date" AS "end_date" FROM "t"'
    )
  end

  it "qualifies each column with the :qualifier option" do
    _(select_sql(:person_id, :end_date, qualifier: :r)).must_equal(
      'SELECT "r"."person_id" AS "person_id", "r"."end_date" AS "end_date" FROM "t"'
    )
  end
end
