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

  describe '#evaluate' do
    it 'adjusts start by 1 day' do
      sql = ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: 'd', end: '' }).evaluate(Sequel.mock).sql
      sql.must_match(%q{date((date(start_date) + interval '1 day')) AS start_date})
      sql.must_match(%q{date(end_date) AS end_date})
    end

    it 'adjusts start by 1 day' do
      sql = ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: '', end: 'd' }).evaluate(Sequel.mock).sql
      sql.must_match(%q{date(start_date) AS start_date})
      sql.must_match(%q{date((date(end_date) + interval '1 day')) AS end_date})
    end

    it 'adjusts both values by 1 day' do
      sql = ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: 'd', end: 'd' }).evaluate(Sequel.mock).sql
      sql.must_match(%q{date((date(start_date) + interval '1 day')) AS start_date, date((date(end_date) + interval '1 day')) AS end_date})
    end

    it 'makes multiple adjustments to both values' do
      sql = ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: 'dmy', end: '-d-m-y' }).evaluate(Sequel.mock).sql
      sql.must_match(%q{date((date((date((date(start_date) + interval '1 day')) + interval '1 month')) + interval '1 year'))})
      sql.must_match(%q{date((date((date((date(end_date) + interval '-1 day')) + interval '-1 month')) + interval '-1 year'))})
    end

    it 'can set start_date to be end_date' do
      sql = ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: 'end', end: '' }).evaluate(Sequel.mock).sql
      sql.must_match(%q{end_date AS start_date})
      sql.must_match(%q{date(end_date) AS end_date})
    end

    it 'can set end_date to be start_date' do
      sql = ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: '', end: 'start' }).evaluate(Sequel.mock).sql
      sql.must_match(%q{start_date AS end_date})
      sql.must_match(%q{date(start_date) AS start_date})
    end

    it 'will swap start and end dates, though this is a bad idea but you should probably know about this' do
      sql = ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: 'end', end: 'start' }).evaluate(Sequel.mock).sql
      sql.must_match(%q{start_date AS end_date})
      sql.must_match(%q{end_date AS start_date})
    end

    it 'handles nil arguments to both start and end' do
      sql = ConceptQL::Nodes::TimeWindow.new(Stream4TimeWindowDouble.new, { start: nil, end: nil }).evaluate(Sequel.mock).sql
      sql.must_match(%q{date(start_date) AS start_date})
      sql.must_match(%q{date(end_date) AS end_date})
    end
  end
end


