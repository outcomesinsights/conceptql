require 'spec_helper'
require 'conceptql/operators/visit_occurrence'
require_double('stream_for_casting')

describe ConceptQL::Operators::VisitOccurrence do
  it_behaves_like(:casting_operator)
end



