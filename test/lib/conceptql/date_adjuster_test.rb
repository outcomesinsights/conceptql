require_relative "../../helper"
require "pp"

describe ConceptQL::DateAdjuster do
  describe ".adjust" do
    let(:op) do
      op = Minitest::Mock.new
      op.expect :rdbms, rdbms
      op
    end

    let(:rdbms) do
      class Rd
        def cast_date(arg)
          arg
        end
      end
      Rd.new
    end

    let(:da) do
      Sequel.extension :date_arithmetic
      ConceptQL::DateAdjuster.new(op, str)
    end

    let(:db) do
      Sequel.mock(host: :postgres)
    end

    describe "with nothing" do
      let(:str) { nil }

      it "should work with nothing" do
        da.adjust(:start_date).value.must_equal("start_date")
      end
    end

    describe "with days" do
      let(:str) { "6d" }

      it "should work with days" do
        da.adjust(:start_date).interval.must_equal({days: 6})
      end
    end

    describe "with weeks" do
      let(:str) { "6w" }

      it "should work with weeks" do
        da.adjust(:start_date).interval.must_equal({days: 42})
      end
    end

    describe "with months" do
      let(:str) { "6m" }

      it "should work with months" do
        da.adjust(:start_date).interval.must_equal({months: 6})
      end
    end

    describe "with years" do
      let(:str) { "6y" }

      it "should work with years" do
        da.adjust(:start_date).interval.must_equal({years: 6})
      end
    end

    describe "with start_date specified as part of end_date adjustment" do
      let(:str) { "S-6y" }

      it "should work" do
        adj = da.adjust(:end_date)
        adj.expr.value.must_equal("start_date")
        adj.interval.must_equal(years: -6)
      end
    end

    describe "with end_date specified as part of start_date adjustment" do
      let(:str) { "E6y" }

      it "should work" do
        adj = da.adjust(:start_date)
        adj.expr.value.must_equal("end_date")
        adj.interval.must_equal(years: 6)
      end
    end

    describe "with end_date specified as part of a QualifiedIdentifier adjustment" do
      let(:str) { "E6y" }

      it "should work" do
        adj = da.adjust(Sequel.qualify(:table, :start_date))
        adj.expr.table.must_equal(:table)
        adj.expr.column.must_equal(:end_date)
        adj.interval.must_equal(years: 6)
      end
    end

    describe "with no digit" do
      let(:str) { "dwmy" }

      it "should pick out each interval" do
        da.adjustments.must_equal([[:days, 1], [:weeks, 1], [:months, 1], [:years, 1]])
      end
    end

    describe "with minuses and no digit" do
      let(:str) { "-dw-my" }

      it "should only subtract days and months" do
        da.adjustments.must_equal([[:days, -1], [:weeks, 1], [:months, -1], [:years, 1]])
      end
    end

    describe "with repeated characters" do
      let(:str) { "ddd" }

      it "should add 3 days" do
        da.adjustments.must_equal([[:days, 1], [:days, 1], [:days, 1]])
      end
    end

    describe "with YYYY-MM-DD" do
      let(:str) { "2001-01-01" }

      it "should use date literal" do
        da.adjust(:end_date).must_equal(str)
      end
    end

    describe "with START" do
      let(:str) { "START" }

      it "should use start_date column" do
        da.adjust(:end_date).must_equal(Sequel[:start_date])
      end
    end

    describe "with END" do
      let(:str) { "END" }

      it "should use end_date column" do
        da.adjust(:start_date).must_equal(Sequel[:end_date])
      end
    end

    describe "with R as prefix" do
      let(:str) { "rddd" }

      it "should reverse the adjustments" do
        da.adjust(:end_date)
        da.adjustments.must_equal([[:days, -1], [:days, -1], [:days, -1]])
      end
    end

    describe "with ER as prefix" do
      let(:str) { "erddd" }

      it "should reverse the adjustments" do
        da.adjust(:end_date)
        da.adjustments.must_equal([[:days, -1], [:days, -1], [:days, -1]])
      end
    end
  end
end


