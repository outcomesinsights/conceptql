require_relative '../../../db_helper'

describe ConceptQL::Rdbms::Postgres do
  let(:db) { Sequel.mock(host: :postgres) }
  let(:rdbms) { ConceptQL::Rdbms::Postgres.new }

  describe "#days_between" do
    it "should use subtractionb between two dates" do
      result = db.literal(rdbms.days_between('2001-01-01', :date_column))

      _(result).must_match('"date_column"')
      _(result).must_match("CAST('2001-01-01' AS date)")
      _(result).must_match("-")
    end
  end
end
