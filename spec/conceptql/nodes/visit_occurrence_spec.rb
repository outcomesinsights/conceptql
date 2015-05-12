require 'spec_helper'
require 'conceptql/operators/visit_occurrence'
require_double('stream_for_casting')

describe ConceptQL::Operators::CastingOperator do
  it 'behaves itself' do
    ConceptQL::Operators::VisitOccurrence.new.must_behave_like(:casting_node)
  end
end



