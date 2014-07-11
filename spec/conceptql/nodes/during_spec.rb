require 'spec_helper'
require 'conceptql/nodes/during'
require_double('stream_for_temporal')

describe ConceptQL::Nodes::During do
  it 'behaves itself' do
    ConceptQL::Nodes::During.new.must_behave_like(:temporal_node)
  end

  describe 'when not inclusive' do
    subject do
      ConceptQL::Nodes::During.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      subject.query(Sequel.mock).sql.must_match 'l.end_date <= r.end_date'
      subject.query(Sequel.mock).sql.must_match 'r.start_date <= l.start_date'
    end
  end

  describe 'when inclusive' do
    subject do
      ConceptQL::Nodes::During.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new, inclusive: true)
    end

    it 'should use proper where clause' do
      subject.query(Sequel.mock).sql.must_match '(r.start_date <= l.end_date) AND (l.end_date <= r.end_date)'
      subject.query(Sequel.mock).sql.must_match '(r.start_date <= l.start_date) AND (l.start_date <= r.end_date)'
    end
  end
end

