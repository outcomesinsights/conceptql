require 'spec_helper'
require 'conceptql/operators/first'
require_double('stream_for_occurrence')

describe ConceptQL::Operators::First do
  it_behaves_like(:evaluator)

  it 'should have occurrence pegged at 1' do
    expect(described_class.new.occurrence).to eq(1)
  end

  describe 'occurrence set to 1' do
    subject do
      described_class.new(StreamForOccurrenceDouble.new).query(Sequel.mock(host: 'postgres')).sql
    end

    it 'should order by ascending start_date' do
      expect(subject).to match('ORDER BY "start_date" ASC')
    end

    it 'should partition by person_id' do
      expect(subject).to match('PARTITION BY "person_id"')
    end

    it 'should assign a row number' do
      expect(subject).to match('row_number()')
    end

    it 'should find the all rows with rn = 1' do
      expect(subject).to match('"rn" = 1')
    end
  end
end


