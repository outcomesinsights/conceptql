require 'spec_helper'
require 'conceptql/nodes/time_window'
require 'conceptql/nodes/node'

describe ConceptQL::Nodes::TimeWindow do
  class Stream4TimeWindowDouble < ConceptQL::Nodes::Node
    def types
      [:visit_occurrence]
    end

    def query(db)
      db
    end
  end

  before do
    @db_mock = Sequel.mock
    @sequel_mock = Minitest::Mock.new
    @sequel_mock.expect :expr, @sequel_mock, [:start_date]
    @sequel_mock.expect :expr, @sequel_mock, [:end_date]
    @sequel_mock.expect :as, @sequel_mock, [:start_date]
    @sequel_mock.expect :as, @sequel_mock, [:end_date]
  end

  describe '#evaluate' do
    it 'adjusts start by 1 day' do
      @sequel_mock.expect :date_add, @sequel_mock, [@sequel_mock, days: 1]

      stub_const(ConceptQL::Nodes::TimeWindow, :Sequel, @sequel_mock) do
        ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: 'd', end: '' }).evaluate(@db_mock)
      end
      @sequel_mock.verify
    end

    it 'adjusts start by 1 day' do
      @sequel_mock.expect :date_add, @sequel_mock, [@sequel_mock, days: 1]
      stub_const(ConceptQL::Nodes::TimeWindow, :Sequel, @sequel_mock) do
        ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: '', end: 'd' }).evaluate(@db_mock)
      end
      @sequel_mock.verify
    end

    it 'adjusts both values by 1 day' do
      @sequel_mock.expect :date_add, @sequel_mock, [@sequel_mock, days: 1]
      @sequel_mock.expect :date_add, @sequel_mock, [@sequel_mock, days: 1]
      stub_const(ConceptQL::Nodes::TimeWindow, :Sequel, @sequel_mock) do
        ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: 'd', end: 'd' }).evaluate(@db_mock)
      end
      @sequel_mock.verify
    end

    it 'makes multiple adjustments to both values' do
      @sequel_mock.expect :date_add, @sequel_mock, [@sequel_mock, days: 1]
      @sequel_mock.expect :date_add, @sequel_mock, [@sequel_mock, months: 1]
      @sequel_mock.expect :date_add, @sequel_mock, [@sequel_mock, years: 1]

      @sequel_mock.expect :date_sub, @sequel_mock, [@sequel_mock, days: 1]
      @sequel_mock.expect :date_sub, @sequel_mock, [@sequel_mock, months: 1]
      @sequel_mock.expect :date_sub, @sequel_mock, [@sequel_mock, years: 1]

      stub_const(ConceptQL::Nodes::TimeWindow, :Sequel, @sequel_mock) do
        ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: 'dmy', end: '-d-m-y' }).evaluate(@db_mock)
      end
      @sequel_mock.verify
    end

    it 'can set start_date to be end_date' do
      ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: 'end', end: '' }).evaluate(@db_mock)
    end

    it 'can set end_date to be start_date' do
      ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: '', end: 'start' }).evaluate(@db_mock)
    end

    it 'will swap start and end dates, though this is a bad idea but you should probably know about this' do
      ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: 'end', end: 'start' }).evaluate(@db_mock)
    end

    it 'handles nil arguments to both start and end' do
      ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: nil, end: nil }).evaluate(@db_mock)
    end
  end
end


