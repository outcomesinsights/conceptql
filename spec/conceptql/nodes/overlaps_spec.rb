require 'spec_helper'
require 'conceptql/nodes/overlaps'
require_double('stream_for_temporal')

describe ConceptQL::Nodes::Overlaps do
  it 'behaves itself' do
    ConceptQL::Nodes::Overlaps.new.must_behave_like(:temporal_node)
  end

  describe 'when not inclusive' do
    subject do
      ConceptQL::Nodes::Overlaps.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      subject.query(Sequel.mock).sql.must_match 'r.start_date <= l.end_date'
      subject.query(Sequel.mock).sql.must_match 'l.start_date <= r.start_date'
      subject.query(Sequel.mock).sql.must_match 'l.end_date <= r.end_date'
    end
  end
end


