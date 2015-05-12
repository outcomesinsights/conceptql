require 'spec_helper'
require 'conceptql/operators/operator'
require 'conceptql/behaviors/dottable'

class OperatorDouble < ConceptQL::Operators::Operator
  include ConceptQL::Behaviors::Dottable

  attr_accessor :values, :options
  def initialize(*values)
    @values = values
    @options = {}
    @types = []
  end
end

describe ConceptQL::Behaviors::Dottable do
  before do
    @obj = OperatorDouble.new
    @obj.must_behave_like(:operator)
  end

  describe '#display_name' do
    it 'should show just the name if no upstreams or arguments' do
      @obj.values = []
      @obj.display_name.must_match(/Operator Double \d+/)
    end

    it 'should show name and args' do
      @obj.values = [5, 10]
      @obj.display_name.must_match(/Operator Double \d+: 5, 10/)
    end

    it 'should not include upstreams' do
      @obj.values = [::ConceptQL::Operators::Operator.new]
      @obj.display_name.must_match(/Operator Double \d+/)
    end
  end

  describe '#operator_name' do
    it 'should show just the name and digit if no upstreams' do
      @obj.values = [::ConceptQL::Operators::Operator.new]
      @obj.operator_name.must_match(/^operator_double_\d+$/)
    end

    it 'should not show args' do
      @obj.values = [5, 10]
      @obj.operator_name.must_match(/^operator_double_\d+$/)
    end

    it 'should not include upstreams' do
      @obj.values = [::ConceptQL::Operators::Operator.new]
      @obj.operator_name.must_match(/^operator_double_\d+$/)
    end
  end

  describe '#graph_it' do
    it 'should add itself as a operator if no upstreams' do
      @obj.values = []
      mock_graph = Minitest::Mock.new
      mock_operator = Minitest::Mock.new
      mock_graph.expect :add_nodes, mock_operator, [@obj.operator_name]
      mock_operator.expect :[]=, nil, [:label, @obj.display_name]
      mock_operator.expect :[]=, nil, [:color, 'black']
      @obj.graph_it(mock_graph, Sequel.mock)

      mock_operator.verify
      mock_graph.verify
    end

    it 'should add its upstreams, then link itself as a operator if upstreams' do
      class MockUpstream < ConceptQL::Operators::Operator
        include ConceptQL::Behaviors::Dottable

        attr_accessor :mock
        def graph_it(graph, db)
          mock.graph_it(graph, db)
        end

        def types
          mock.types
        end

        def link_to(mock_graph, mock_operator, db)
          mock.link_to(mock_graph, mock_operator, db)
        end
      end

      mock_operator = Minitest::Mock.new
      mock_operator.expect :[]=, nil, [:label, @obj.display_name]
      mock_operator.expect :[]=, nil, [:color, 'black']

      mock_graph = Minitest::Mock.new
      mock_graph.expect :add_nodes, mock_operator, [@obj.operator_name]

      mock_upstream = MockUpstream.new
      mock_upstream.mock = Minitest::Mock.new
      mock_upstream.mock.expect :graph_it, :upstream_operator, [mock_graph, :db]
      mock_upstream.mock.expect :link_to, nil, [mock_graph, mock_operator, :db]

      mock_upstream.must_behave_like(:operator)

      @obj.values = [mock_upstream]

      @obj.graph_it(mock_graph, :db)

      mock_operator.verify
      mock_graph.verify
      mock_upstream.mock.verify
    end
  end
end
