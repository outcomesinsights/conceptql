require 'spec_helper'
require 'conceptql/nodes/date_range'

describe ConceptQL::Nodes::DateRange do
  it 'behaves itself' do
    ConceptQL::Nodes::DateRange.new.must_behave_like(:evaluator)
  end

  describe '#types' do
    it 'should be [:date]' do
      ConceptQL::Nodes::DateRange.new(start: '2004-12-13', end: '2010-03-20').types.must_equal([:person])
    end
  end

  describe '#query' do
    it 'should be dates specified assigned to all persons' do
      ConceptQL::Nodes::DateRange.new(start: '2004-12-13', end: '2010-03-20').query(Sequel.mock).sql.must_equal("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, date '2004-12-13' AS start_date, date '2010-03-20' AS end_date FROM person) AS t1")
    end

    it 'should handle strings for option keys' do
      ConceptQL::Nodes::DateRange.new('start' => '2004-12-13', 'end' => '2010-03-20').query(Sequel.mock).sql.must_equal("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, date '2004-12-13' AS start_date, date '2010-03-20' AS end_date FROM person) AS t1")
    end

    it 'handles START as day before first recorded visit_occurrence' do
      ConceptQL::Nodes::DateRange.new(start: 'START', end: '2010-03-20').query(Sequel.mock).sql.must_equal("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, (SELECT min(start_date) FROM visit_occurrence) AS start_date, date '2010-03-20' AS end_date FROM person) AS t1")
    end

    it 'handles END as 2010-12-31' do
      ConceptQL::Nodes::DateRange.new(start: '2004-12-13', end: 'END').query(Sequel.mock).sql.must_equal("SELECT * FROM (SELECT *, CAST('person' AS varchar(255)) AS criterion_type, person_id AS criterion_id, date '2004-12-13' AS start_date, (SELECT max(end_date) FROM visit_occurrence) AS end_date FROM person) AS t1")
    end
  end

end


