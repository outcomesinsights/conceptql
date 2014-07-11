require 'spec_helper'
require 'conceptql/nodes/procedure_occurrence'
require_double('stream_for_casting')

describe ConceptQL::Nodes::CastingNode do
  it 'behaves itself' do
    ConceptQL::Nodes::ProcedureOccurrence.new.must_behave_like(:casting_node)
  end
end



