require 'spec_helper'
require 'conceptql/nodes/node'
require 'conceptql/behaviors/dottable'

class NodeDouble < ConceptQL::Nodes::Node
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
    it 'should show just the name if no children or arguments' do
      @obj.values = []
      @obj.display_name.must_equal 'Node Double'
    end

    it 'should show name and args' do
      @obj.values = [5, 10]
      @obj.display_name.must_equal 'Node Double: 5, 10'
    end

    it 'should not include children' do
      @obj.values = [::ConceptQL::Nodes::Node.new]
      @obj.display_name.must_equal 'Node Double'
    end
  end

  describe '#node_name' do
    it 'should show just the name and digit if no children' do
      @obj.values = [::ConceptQL::Nodes::Node.new]
      @obj.node_name.must_match(/^node_double_\d+$/)
    end

    it 'should not show args' do
      @obj.values = [5, 10]
      @obj.node_name.must_match(/^node_double_\d+$/)
    end

    it 'should not include children' do
      @obj.values = [::ConceptQL::Nodes::Node.new]
      @obj.node_name.must_match(/^node_double_\d+$/)
    end
  end

  describe '#graph_it' do
    it 'should add itself as a node if no children' do
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

    it 'should add its children, then link itself as a node if children' do
      class MockChild < ConceptQL::Nodes::Node
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

      mock_child = MockChild.new
      mock_child.mock = Minitest::Mock.new
      mock_child.mock.expect :graph_it, :child_node, [mock_graph, :db]
      mock_child.mock.expect :link_to, nil, [mock_graph, mock_node, :db]

      mock_child.must_behave_like(:node)

      @obj.values = [mock_child]

      @obj.graph_it(mock_graph, :db)

      mock_node.verify
      mock_graph.verify
      mock_child.mock.verify
    end
  end
end
