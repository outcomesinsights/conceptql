require 'spec_helper'
require 'conceptql/operators/person'
require_double('stream_for_casting')

describe ConceptQL::Operators::CastingOperator do
  it 'behaves itself' do
    ConceptQL::Operators::Person.new.must_behave_like(:casting_node)
  end
end



