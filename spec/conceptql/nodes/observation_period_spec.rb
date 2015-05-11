require 'spec_helper'
require 'conceptql/nodes/observation_period'
require_double('stream_for_casting')

describe ConceptQL::Operators::CastingNode do
  it 'behaves itself' do
    ConceptQL::Operators::ObservationPeriod.new.must_behave_like(:casting_node)
  end
end



