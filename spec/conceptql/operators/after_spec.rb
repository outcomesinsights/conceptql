require 'spec_helper'
require 'conceptql/operators/after'
require_double('stream_for_temporal')

describe ConceptQL::Operators::After do
  it_behaves_like(:temporal_operator)

  subject do
    described_class.new(left: StreamForTemporalDouble.new, right: StreamForTemporalDouble.new)
  end

  it 'should use proper where clause' do
    expect(subject.query(Sequel.mock).sql).to match('l.start_date > r.end_date')
  end
end

