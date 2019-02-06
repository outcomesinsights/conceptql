require_relative '../../../db_helper'

describe ConceptQL::Rdbms::Impala do
  let(:db) { Sequel.mock(host: :impala) }
  let(:rdbms) { ConceptQL::Rdbms::Impala.new }

  describe "#days_between" do
    it "should use datediff function" do
      result = db.literal(rdbms.days_between('2001-01-01', :date_column))

      result.must_match("`date_column`")
      result.must_match("CAST('2001-01-01' AS timestamp)")
      result.must_match("datediff")
    end
  end
end
