require 'spec_helper'
require 'conceptql/nodes/before'
require_double('stream_for_temporal')

describe ConceptQL::Nodes::Before do
  it 'behaves itself' do
    ConceptQL::Nodes::Before.new.must_behave_like(:temporal_node)
  end

  subject do
    ConceptQL::Nodes::Before.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
  end

  it 'should use proper where clause' do
    subject.query(Sequel.mock).sql.must_match 'l.end_date < r.start_date'
  end
end

