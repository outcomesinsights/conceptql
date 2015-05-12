require 'spec_helper'
require 'conceptql/operators/observation_period'
require_double('stream_for_casting')

describe ConceptQL::Operators::CastingOperator do
  it 'behaves itself' do
    ConceptQL::Operators::ObservationPeriod.new.must_behave_like(:casting_operator)
  end
end



