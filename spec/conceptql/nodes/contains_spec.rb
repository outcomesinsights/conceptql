require 'spec_helper'
require 'conceptql/operators/contains'
require_double('stream_for_temporal')

describe ConceptQL::Operators::Contains do
  it_behaves_like(:temporal_operator)

  describe 'when not inclusive' do
    subject do
      described_class.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      expect(subject.query(Sequel.mock).sql).to match('r.end_date <= l.end_date')
      expect(subject.query(Sequel.mock).sql).to match('l.start_date <= r.start_date')
    end
  end
end

