require 'spec_helper'
require 'conceptql/operators/date_range'

describe ConceptQL::Operators::DateRange do
  it_behaves_like(:evaluator)

  describe '#types' do
    it 'should be [:date]' do
      expect(ConceptQL::Operators::DateRange.new(start: '2004-12-13', end: '2010-03-20').types).to eq([:person])
    end
  end

  describe '#query' do
    it 'should be dates specified assigned to all persons' do
      expect(ConceptQL::Operators::DateRange.new(start: '2004-12-13', end: '2010-03-20').query(Sequel.mock).sql).to eq("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, date '2004-12-13' AS start_date, date '2010-03-20' AS end_date FROM person) AS t1")
    end

    it 'should handle strings for option keys' do
      expect(ConceptQL::Operators::DateRange.new('start' => '2004-12-13', 'end' => '2010-03-20').query(Sequel.mock).sql).to eq("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, date '2004-12-13' AS start_date, date '2010-03-20' AS end_date FROM person) AS t1")
    end

    it 'handles START as day before first recorded observation_period' do
      expect(ConceptQL::Operators::DateRange.new(start: 'START', end: '2010-03-20').query(Sequel.mock).sql).to eq("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, (SELECT min(observation_period_start_date) FROM observation_period) AS start_date, date '2010-03-20' AS end_date FROM person) AS t1")
    end

    it 'handles END as last date of recorded observation_period' do
      expect(ConceptQL::Operators::DateRange.new(start: '2004-12-13', end: 'END').query(Sequel.mock).sql).to eq("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, date '2004-12-13' AS start_date, (SELECT max(observation_period_end_date) FROM observation_period) AS end_date FROM person) AS t1")
    end
  end

end


