require 'spec_helper'
require 'conceptql/operators/contains'
require_double('stream_for_temporal')

describe ConceptQL::Operators::Contains do
  it 'behaves itself' do
    ConceptQL::Operators::Contains.new.must_behave_like(:temporal_node)
  end

  describe 'when not inclusive' do
    subject do
      ConceptQL::Operators::Contains.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      subject.query(Sequel.mock).sql.must_match 'r.end_date <= l.end_date'
      subject.query(Sequel.mock).sql.must_match 'l.start_date <= r.start_date'
    end
  end
end

