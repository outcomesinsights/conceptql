require 'spec_helper'
require 'conceptql/operators/operator'
require 'conceptql/behaviors/dottable'

class OperatorDouble < ConceptQL::Operators::Operator
  include ConceptQL::Behaviors::Dottable

  def initialize(*args)
    super
    @types = []
  end
end

describe ConceptQL::Behaviors::Dottable do
  before do
    @obj = OperatorDouble.new
  end

  describe '#display_name' do
    it 'should show just the name if no upstreams or arguments' do
      @obj.values = []
      expect(@obj.display_name).to match(/Operator Double( \d+)?/)
    end

    it 'should show name and args' do
      @obj.values = [5, 10]
      expect(@obj.display_name).to match(/Operator Double( \d+)?: 5, 10/)
    end

    it 'should not include upstreams' do
      @obj.values = [::ConceptQL::Operators::Operator.new]
      expect(@obj.display_name).to match(/Operator Double( \d+)?/)
    end
  end

  describe '#operator_name' do
    it 'should show just the name and digit if no upstreams' do
      @obj.values = [::ConceptQL::Operators::Operator.new]
      expect(@obj.operator_name).to match(/^operator_double_\d+$/)
    end

    it 'should not show args' do
      @obj.values = [5, 10]
      expect(@obj.operator_name).to match(/^operator_double_\d+$/)
    end

    it 'should not include upstreams' do
      @obj.values = [::ConceptQL::Operators::Operator.new]
      expect(@obj.operator_name).to match(/^operator_double_\d+$/)
    end
  end

  describe '#graph_it' do
    it 'should add itself as a operator if no upstreams' do
      @obj.values = []
      mock_graph = double("graph")
      mock_operator = double("operator")
      expect(mock_graph).to receive(:add_nodes).with(@obj.operator_name).and_return(mock_operator)
      expect(mock_operator).to receive(:[]=).with(:label, @obj.display_name).and_return(nil)
      expect(mock_operator).to receive(:[]=).with(:color, 'black').and_return(nil)
      @obj.graph_it(mock_graph, Sequel.mock)
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

      mock_operator = double("operator")
      expect(mock_operator).to receive(:[]=).with(:label, @obj.display_name).and_return(nil)
      expect(mock_operator).to receive(:[]=).with(:color, 'black').and_return(nil)

      mock_graph = double("graph")
      expect(mock_graph).to receive(:add_nodes).with(@obj.operator_name).and_return(mock_operator)

      mock_upstream = MockUpstream.new
      mock_upstream.mock = double("upstream")
      expect(mock_upstream.mock).to receive(:graph_it).with(mock_graph, :db).and_return(:upstream_operator)
      expect(mock_upstream.mock).to receive(:link_to).with(mock_graph, mock_operator, :db).and_return(nil)

      @obj.values = mock_upstream

      @obj.graph_it(mock_graph, :db)
    end
  end
end
