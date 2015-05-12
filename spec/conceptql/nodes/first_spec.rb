require 'spec_helper'
require 'conceptql/operators/first'
require_double('stream_for_occurrence')

describe ConceptQL::Operators::First do
  it 'behaves itself' do
    ConceptQL::Operators::First.new.must_behave_like(:evaluator)
  end

  it 'should have occurrence pegged at 1' do
    ConceptQL::Operators::First.new.occurrence.must_equal(1)
  end

  describe 'occurrence set to 1' do
    subject do
      ConceptQL::Operators::First.new(StreamForOccurrenceDouble.new).query(Sequel.mock(host: 'postgres')).sql
    end

    it 'should order by ascending start_date' do
      subject.must_match 'ORDER BY "start_date" ASC'
    end

    it 'should partition by person_id' do
      subject.must_match 'PARTITION BY "person_id"'
    end

    it 'should assign a row number' do
      subject.must_match 'row_number()'
    end

    it 'should find the all rows with rn = 1' do
      subject.must_match '"rn" = 1'
    end
  end
end


