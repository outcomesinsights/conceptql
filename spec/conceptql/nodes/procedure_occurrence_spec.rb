require 'spec_helper'
require 'conceptql/operators/procedure_occurrence'
require_double('stream_for_casting')

describe ConceptQL::Operators::CastingOperator do
  it 'behaves itself' do
    ConceptQL::Operators::ProcedureOccurrence.new.must_behave_like(:casting_operator)
  end
end



