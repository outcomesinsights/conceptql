require 'spec_helper'
require 'conceptql/operators/before'
require_double('stream_for_temporal')

describe ConceptQL::Operators::Before do
  it 'behaves itself' do
    ConceptQL::Operators::Before.new.must_behave_like(:temporal_operator)
  end

  subject do
    ConceptQL::Operators::Before.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
  end

  it 'should use proper where clause' do
    subject.query(Sequel.mock).sql.must_match 'l.end_date < r.start_date'
  end
end

