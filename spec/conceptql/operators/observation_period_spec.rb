require 'spec_helper'
require 'conceptql/operators/observation_period'
require_double('stream_for_casting')

describe ConceptQL::Operators::ObservationPeriod do
  it_behaves_like(:casting_operator)
end



