require 'spec_helper'
require 'conceptql/nodes/date_range'

describe ConceptQL::Operators::DateRange do
  it 'behaves itself' do
    ConceptQL::Operators::DateRange.new.must_behave_like(:evaluator)
  end

  describe '#types' do
    it 'should be [:date]' do
      ConceptQL::Operators::DateRange.new(start: '2004-12-13', end: '2010-03-20').types.must_equal([:person])
    end
  end

  describe '#query' do
    it 'should be dates specified assigned to all persons' do
      ConceptQL::Operators::DateRange.new(start: '2004-12-13', end: '2010-03-20').query(Sequel.mock).sql.must_equal("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, date '2004-12-13' AS start_date, date '2010-03-20' AS end_date FROM person) AS t1")
    end

    it 'should handle strings for option keys' do
      ConceptQL::Operators::DateRange.new('start' => '2004-12-13', 'end' => '2010-03-20').query(Sequel.mock).sql.must_equal("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, date '2004-12-13' AS start_date, date '2010-03-20' AS end_date FROM person) AS t1")
    end

    it 'handles START as day before first recorded observation_period' do
      ConceptQL::Operators::DateRange.new(start: 'START', end: '2010-03-20').query(Sequel.mock).sql.must_equal("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, (SELECT min(observation_period_start_date) FROM observation_period) AS start_date, date '2010-03-20' AS end_date FROM person) AS t1")
    end

    it 'handles END as last date of recorded observation_period' do
      ConceptQL::Operators::DateRange.new(start: '2004-12-13', end: 'END').query(Sequel.mock).sql.must_equal("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, date '2004-12-13' AS start_date, (SELECT max(observation_period_end_date) FROM observation_period) AS end_date FROM person) AS t1")
    end
  end

end


