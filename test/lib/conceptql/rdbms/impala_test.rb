require_relative '../../../helper'

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

  describe "#partition_fix" do
    it "should apply fix by default" do
      result = db.literal(rdbms.partition_fix(:some_column))

      result.must_match("concat")
      result.must_match("AS string")
      result.must_match("'_'")
      result.must_match("some_column")
      result.must_match("person_id")
    end

    it "should NOT apply fix if CONCEPTQL_DISABLE_ORDER_BY_FIX is set to 'true'" do
      begin
        save_disable = ENV["CONCEPTQL_DISABLE_ORDER_BY_FIX"]
        ENV["CONCEPTQL_DISABLE_ORDER_BY_FIX"] = "true"
        result = db.literal(rdbms.partition_fix(:some_column))

        result.must_match("some_column")
        result.wont_match("concat")
        result.wont_match("AS string")
        result.wont_match("'_'")
        result.wont_match("person_id")
      ensure
        ENV["CONCEPTQL_DISABLE_ORDER_BY_FIX"] = save_disable
      end
    end
  end
end
