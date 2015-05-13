require 'spec_helper'
require 'conceptql/operators/death'
require_double('stream_for_casting')

describe ConceptQL::Operators::Death do
  it_behaves_like(:casting_operator)
end



