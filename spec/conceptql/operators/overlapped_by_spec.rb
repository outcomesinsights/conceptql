require 'spec_helper'
require 'conceptql/operators/overlapped_by'
require_double('stream_for_temporal')

describe ConceptQL::Operators::OverlappedBy do
  it_behaves_like(:temporal_operator)

  describe 'when not inclusive' do
    subject do
      described_class.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      expect(subject.query(Sequel.mock).sql).to match('l.start_date <= r.end_date')
      expect(subject.query(Sequel.mock).sql).to match('r.start_date <= l.start_date')
      expect(subject.query(Sequel.mock).sql).to match('r.end_date <= l.end_date')
    end
  end

  describe 'when inclusive' do
    subject do
      described_class.new(inclusive: true, left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      expect(subject.query(Sequel.mock).sql).to match('l.start_date <= r.end_date')
      expect(subject.query(Sequel.mock).sql).to match('r.start_date <= l.start_date')
    end
  end
end


