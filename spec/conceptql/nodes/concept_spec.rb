require 'spec_helper'
require 'conceptql/nodes/concept'

describe ConceptQL::Nodes::Concept do
  it 'behaves itself' do
    ConceptQL::Nodes::Concept.new.must_behave_like(:evaluator)
  end

  class ConceptDouble < ConceptQL::Nodes::Concept
    def arguments
      [1]
    end

    def set_statement(value)
      # Do Nothing
    end

    def stream
      @stream ||= Minitest::Mock.new
    end
  end

  describe '#query' do
    it 'evaluates child' do
      cd = ConceptDouble.new(1)
      cd.stream.expect :evaluate, nil, [:db]
      cd.query(:db)
      cd.stream.verify
    end
  end
end



