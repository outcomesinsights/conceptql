require 'spec_helper'
require 'conceptql/nodes/from'
require_relative 'query_double'

describe ConceptQL::Nodes::From do
  it 'behaves itself' do
    ConceptQL::Nodes::From.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'works for single criteria' do
      ConceptQL::Nodes::From.new(:table1).query(Sequel.mock).sql.must_equal "SELECT * FROM table1"
    end
  end
end
