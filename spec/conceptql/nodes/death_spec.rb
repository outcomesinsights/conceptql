require 'spec_helper'
require 'conceptql/operators/death'
require_double('stream_for_casting')

describe ConceptQL::Operators::CastingOperator do
  it 'behaves itself' do
    ConceptQL::Operators::Death.new.must_behave_like(:casting_operator)
  end
end



