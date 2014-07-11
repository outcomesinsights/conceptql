require 'spec_helper'
require 'conceptql/nodes/death'
require_double('stream_for_casting')

describe ConceptQL::Nodes::CastingNode do
  it 'behaves itself' do
    ConceptQL::Nodes::Death.new.must_behave_like(:casting_node)
  end
end



