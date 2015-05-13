require 'spec_helper'
require 'conceptql/operators/time_window'
require 'conceptql/operators/operator'

describe ConceptQL::Operators::TimeWindow do
  class Stream4TimeWindowDouble < ConceptQL::Operators::Operator
    def types
      [:visit_occurrence]
    end

    def query(db)
      db.from(:table)
    end
  end

  let (:sequel_mock) do
    sequel_mock = double("sequel")
  end

  before do
    @db_mock = Sequel.mock
  end

  describe '#evaluate' do
    it 'adjusts start by 1 day' do
      expect(sequel_mock).to receive(:date_add).with(Sequel.identifier("start_date"), days: 1).and_return(sequel_mock)
      expect(@db_mock).to receive(:extension).with(:date_arithmetic)

      described_class.new(Stream4TimeWindowDouble.new, { start: 'd', end: '', date_manipulator: sequel_mock }).evaluate(@db_mock)
    end

    it 'adjusts end by 1 day' do
      expect(sequel_mock).to receive(:date_add).with(Sequel.identifier("end_date"), days: 1).and_return(sequel_mock)
      described_class.new(Stream4TimeWindowDouble.new, { start: '', end: 'd', date_manipulator: sequel_mock }).evaluate(@db_mock)
    end

    it 'adjusts both values by 1 day' do
      expect(sequel_mock).to receive(:date_add).with(Sequel.identifier("start_date"), days: 1).and_return(sequel_mock)
      expect(sequel_mock).to receive(:date_add).with(Sequel.identifier("end_date"), days: 1).and_return(sequel_mock)
      described_class.new(Stream4TimeWindowDouble.new, { start: 'd', end: 'd', date_manipulator: sequel_mock }).evaluate(@db_mock)
    end

    it 'makes multiple adjustments to both values' do
      expect(sequel_mock).to receive(:date_add).with(Sequel.identifier("start_date"), days: 1).and_return(sequel_mock)
      expect(sequel_mock).to receive(:date_add).with(sequel_mock, months: 1).and_return(sequel_mock)
      expect(sequel_mock).to receive(:date_add).with(sequel_mock, years: 1).and_return(sequel_mock)

      expect(sequel_mock).to receive(:date_sub).with(Sequel.identifier("end_date"), days: 1).and_return(sequel_mock)
      expect(sequel_mock).to receive(:date_sub).with(sequel_mock, months: 1).and_return(sequel_mock)
      expect(sequel_mock).to receive(:date_sub).with(sequel_mock, years: 1).and_return(sequel_mock)

      described_class.new(Stream4TimeWindowDouble.new, { start: 'dmy', end: '-d-m-y', date_manipulator: sequel_mock }).evaluate(@db_mock)
    end

    it 'can set start_date and end_date to specific dates' do
      described_class.new(Stream4TimeWindowDouble.new, { start: '2000-01-01', end: '2000-02-02' }).evaluate(@db_mock)
    end

    it 'can set start_date to be end_date' do
      described_class.new(Stream4TimeWindowDouble.new, { start: 'end', end: '' }).evaluate(@db_mock)
    end

    it 'can set end_date to be start_date' do
      described_class.new(Stream4TimeWindowDouble.new, { start: '', end: 'start' }).evaluate(@db_mock)
    end

    it 'will swap start and end dates, though this is a bad idea but you should probably know about this' do
      described_class.new(Stream4TimeWindowDouble.new, { start: 'end', end: 'start' }).evaluate(@db_mock)
    end

    it 'handles nil arguments to both start and end' do
      described_class.new(Stream4TimeWindowDouble.new, { start: nil, end: nil }).evaluate(@db_mock)
    end
  end
end


