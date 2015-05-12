require 'spec_helper'
require 'conceptql/operators/occurrence'
require_double('stream_for_occurrence')

describe ConceptQL::Operators::Occurrence do
  it 'behaves itself' do
    ConceptQL::Operators::Occurrence.new.must_behave_like(:evaluator)
  end

  describe 'occurrence set to 1' do
    subject do
      ConceptQL::Operators::Occurrence.new(1, StreamForOccurrenceDouble.new).query(Sequel.mock(host: 'postgres')).sql
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

    it 'should find the all rows with "rn" = 1' do
      subject.must_match '"rn" = 1'
    end
  end

  describe 'occurrence set to 2' do
    subject do
      ConceptQL::Operators::Occurrence.new(2, StreamForOccurrenceDouble.new).query(Sequel.mock(host: 'postgres')).sql
    end

    it 'should order by ascending start_date' do
      subject.must_match 'ORDER BY "start_date" ASC'
    end

    it 'should find the all rows with "rn" = 2' do
      subject.must_match '"rn" = 2'
    end
  end

  describe 'occurrence set to -1' do
    subject do
      ConceptQL::Operators::Occurrence.new(-1, StreamForOccurrenceDouble.new).query(Sequel.mock(host: 'postgres')).sql
    end

    it 'should order by ascending start_date' do
      subject.must_match 'ORDER BY "start_date" DESC'
    end

    it 'should find the all rows with "rn" = 1' do
      subject.must_match '"rn" = 1'
    end
  end

  describe 'occurrence set to -2' do
    subject do
      ConceptQL::Operators::Occurrence.new(-2, StreamForOccurrenceDouble.new).query(Sequel.mock(host: 'postgres')).sql
    end

    it 'should order by ascending start_date' do
      subject.must_match 'ORDER BY "start_date" DESC'
    end

    it 'should find the all rows with "rn" = 2' do
      subject.must_match '"rn" = 2'
    end
  end

  describe 'occurrence respects types' do
    subject do
      dub = StreamForOccurrenceDouble.new
      def dub.types
        [:condition_occurrence]
      end
      ConceptQL::Operators::Occurrence.new(-2, dub).query(Sequel.mock(host: 'postgres')).sql
    end

    it 'should order by ascending start_date' do
      subject.must_match ', "criterion_type", "criterion_id"'
    end
  end
end


