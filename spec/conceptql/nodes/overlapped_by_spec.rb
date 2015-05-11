require 'spec_helper'
require 'conceptql/nodes/overlapped_by'
require_double('stream_for_temporal')

describe ConceptQL::Operators::OverlappedBy do
  it 'behaves itself' do
    ConceptQL::Operators::OverlappedBy.new.must_behave_like(:temporal_node)
  end

  describe 'when not inclusive' do
    subject do
      ConceptQL::Operators::OverlappedBy.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      subject.query(Sequel.mock).sql.must_match 'l.start_date <= r.end_date'
      subject.query(Sequel.mock).sql.must_match 'r.start_date <= l.start_date'
      subject.query(Sequel.mock).sql.must_match 'r.end_date <= l.end_date'
    end
  end

  describe 'when inclusive' do
    subject do
      ConceptQL::Operators::OverlappedBy.new(inclusive: true, left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
    end

    it 'should use proper where clause' do
      subject.query(Sequel.mock).sql.must_match 'l.start_date <= r.end_date'
      subject.query(Sequel.mock).sql.must_match 'r.start_date <= l.start_date'
      subject.query(Sequel.mock).sql.must_match 'r.end_date <= l.end_date'
      subject.query(Sequel.mock).sql.must_match ' OR '
      subject.query(Sequel.mock).sql.must_match 'r.start_date <= l.start_date'
      subject.query(Sequel.mock).sql.must_match 'l.end_date <= r.end_date'
    end
  end
end


