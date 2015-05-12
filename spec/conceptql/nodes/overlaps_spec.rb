require 'spec_helper'
require 'conceptql/operators/overlaps'
require_double('stream_for_temporal')

describe ConceptQL::Operators::Overlaps do
  it 'behaves itself' do
    ConceptQL::Operators::Overlaps.new.must_behave_like(:temporal_operator)
  end

  describe 'when not inclusive' do
    subject do
      ConceptQL::Operators::Overlaps.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      subject.query(Sequel.mock).sql.must_match 'r.start_date <= l.end_date'
      subject.query(Sequel.mock).sql.must_match 'l.start_date <= r.start_date'
      subject.query(Sequel.mock).sql.must_match 'l.end_date <= r.end_date'
    end
  end
end


