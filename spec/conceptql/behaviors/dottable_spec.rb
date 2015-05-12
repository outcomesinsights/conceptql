require 'spec_helper'
require 'conceptql/nodes/operator'
require 'conceptql/behaviors/dottable'

class NodeDouble < ConceptQL::Operators::Operator
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
    @obj = NodeDouble.new
    @obj.must_behave_like(:node)
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

  describe '#node_name' do
    it 'should show just the name and digit if no upstreams' do
      @obj.values = [::ConceptQL::Operators::Operator.new]
      @obj.node_name.must_match(/^node_double_\d+$/)
    end

    it 'should not show args' do
      @obj.values = [5, 10]
      @obj.node_name.must_match(/^node_double_\d+$/)
    end

    it 'should not include upstreams' do
      @obj.values = [::ConceptQL::Operators::Operator.new]
      @obj.node_name.must_match(/^node_double_\d+$/)
    end
  end

  describe '#graph_it' do
    it 'should add itself as a node if no upstreams' do
      @obj.values = []
      mock_graph = Minitest::Mock.new
      mock_node = Minitest::Mock.new
      mock_graph.expect :add_nodes, mock_node, [@obj.node_name]
      mock_node.expect :[]=, nil, [:label, @obj.display_name]
      mock_node.expect :[]=, nil, [:color, 'black']
      @obj.graph_it(mock_graph, Sequel.mock)

      mock_node.verify
      mock_graph.verify
    end

    it 'should add its upstreams, then link itself as a node if upstreams' do
      class MockUpstream < ConceptQL::Operators::Operator
        include ConceptQL::Behaviors::Dottable

        attr_accessor :mock
        def graph_it(graph, db)
          mock.graph_it(graph, db)
        end

        def types
          mock.types
        end

        def link_to(mock_graph, mock_node, db)
          mock.link_to(mock_graph, mock_node, db)
        end
      end

      mock_node = Minitest::Mock.new
      mock_node.expect :[]=, nil, [:label, @obj.display_name]
      mock_node.expect :[]=, nil, [:color, 'black']

      mock_graph = Minitest::Mock.new
      mock_graph.expect :add_nodes, mock_node, [@obj.node_name]

      mock_upstream = MockUpstream.new
      mock_upstream.mock = Minitest::Mock.new
      mock_upstream.mock.expect :graph_it, :upstream_node, [mock_graph, :db]
      mock_upstream.mock.expect :link_to, nil, [mock_graph, mock_node, :db]

      mock_upstream.must_behave_like(:node)

      @obj.values = [mock_upstream]

      @obj.graph_it(mock_graph, :db)

      mock_node.verify
      mock_graph.verify
      mock_upstream.mock.verify
    end
  end
end
