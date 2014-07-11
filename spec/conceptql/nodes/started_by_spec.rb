require 'spec_helper'
require 'conceptql/nodes/started_by'
require_double('stream_for_temporal')

describe ConceptQL::Nodes::StartedBy do
  it 'behaves itself' do
    ConceptQL::Nodes::StartedBy.new.must_behave_like(:temporal_node)
  end

  subject do
    ConceptQL::Nodes::StartedBy.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
  end

  it 'should use proper where clause' do
    subject.query(Sequel.mock).sql.must_match 'l.start_date = r.start_date'
    subject.query(Sequel.mock).sql.must_match 'l.end_date > r.end_date'
  end

  it 'should use proper where clause when inclusive' do
    sub = ConceptQL::Nodes::StartedBy.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new, inclusive: true)
    sub.query(Sequel.mock).sql.must_match 'l.start_date = r.start_date'
    sub.query(Sequel.mock).sql.must_match 'l.end_date >= r.end_date'
  end
end

