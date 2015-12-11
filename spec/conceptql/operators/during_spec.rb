require 'spec_helper'
require 'conceptql/operators/during'
require_double('stream_for_temporal')

describe ConceptQL::Operators::During do
  it_behaves_like(:temporal_operator)

  describe 'when not inclusive' do
    subject do
      described_class.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      expect(subject.query(Sequel.mock).sql).to match('l.end_date <= r.end_date')
      expect(subject.query(Sequel.mock).sql).to match('r.start_date <= l.start_date')
    end
  end

  describe 'when inclusive' do
    subject do
      described_class.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new, inclusive: true)
    end

    it 'should use proper where clause' do
      expect(subject.query(Sequel.mock).sql).to match(/\(r.start_date <= l.end_date\) AND \(l.end_date <= r.end_date\)/)
      expect(subject.query(Sequel.mock).sql).to match(/\(r.start_date <= l.start_date\) AND \(l.start_date <= r.end_date\)/)
    end
  end
end

