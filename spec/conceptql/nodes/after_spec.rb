require 'spec_helper'
require 'conceptql/operators/after'
require_double('stream_for_temporal')

describe ConceptQL::Operators::After do
  it 'behaves itself' do
    ConceptQL::Operators::After.new.must_behave_like(:temporal_operator)
  end

  subject do
    ConceptQL::Operators::After.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
  end

  it 'should use proper where clause' do
    subject.query(Sequel.mock).sql.must_match 'l.start_date > r.end_date'
  end
end

