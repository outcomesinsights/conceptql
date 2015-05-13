require 'spec_helper'
require 'conceptql/operators/overlaps'
require_double('stream_for_temporal')

describe ConceptQL::Operators::Overlaps do
  it_behaves_like(:temporal_operator)

  describe 'when not inclusive' do
    subject do
      described_class.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      expect(subject.query(Sequel.mock).sql).to match('r.start_date <= l.end_date')
      expect(subject.query(Sequel.mock).sql).to match('l.start_date <= r.start_date')
      expect(subject.query(Sequel.mock).sql).to match('l.end_date <= r.end_date')
    end
  end
end


