require 'spec_helper'
require 'conceptql/operators/occurrence'
require_double('stream_for_occurrence')

describe ConceptQL::Operators::Occurrence do
  it_behaves_like(:evaluator)

  describe 'occurrence set to 1' do
    subject do
      described_class.new(1, StreamForOccurrenceDouble.new).query(Sequel.mock(host: 'postgres')).sql
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

    it 'should find the all rows with "rn" = 1' do
      expect(subject).to match('"rn" = 1')
    end
  end

  describe 'occurrence set to 2' do
    subject do
      described_class.new(2, StreamForOccurrenceDouble.new).query(Sequel.mock(host: 'postgres')).sql
    end

    it 'should order by ascending start_date' do
      expect(subject).to match('ORDER BY "start_date" ASC')
    end

    it 'should find the all rows with "rn" = 2' do
      expect(subject).to match('"rn" = 2')
    end
  end

  describe 'occurrence set to -1' do
    subject do
      described_class.new(-1, StreamForOccurrenceDouble.new).query(Sequel.mock(host: 'postgres')).sql
    end

    it 'should order by ascending start_date' do
      expect(subject).to match('ORDER BY "start_date" DESC')
    end

    it 'should find the all rows with "rn" = 1' do
      expect(subject).to match('"rn" = 1')
    end
  end

  describe 'occurrence set to -2' do
    subject do
      described_class.new(-2, StreamForOccurrenceDouble.new).query(Sequel.mock(host: 'postgres')).sql
    end

    it 'should order by ascending start_date' do
      expect(subject).to match('ORDER BY "start_date" DESC')
    end

    it 'should find the all rows with "rn" = 2' do
      expect(subject).to match('"rn" = 2')
    end
  end

  describe 'occurrence respects types' do
    subject do
      dub = StreamForOccurrenceDouble.new
      def dub.types
        [:condition_occurrence]
      end
      described_class.new(-2, dub).query(Sequel.mock(host: 'postgres')).sql
    end

    it 'should order by ascending start_date' do
      expect(subject).to match(', "criterion_type", "criterion_id"')
    end
  end
end


