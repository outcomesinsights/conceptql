require 'spec_helper'
require 'conceptql/operators/procedure_occurrence'
require_double('stream_for_casting')

describe ConceptQL::Operators::ProcedureOccurrence do
  it_behaves_like(:casting_operator)
end



