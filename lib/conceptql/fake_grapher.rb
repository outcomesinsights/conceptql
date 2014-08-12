require_relative 'graph'
require_relative 'tree'
require_relative 'graph_nodifier'

module ConceptQL
  class FakeGrapher
    attr :options

    def initialize(options = {})
      @options = {
        dangler: true,
        tree: ConceptQL::Tree.new(nodifier: ConceptQL::GraphNodifier.new)
      }.merge(options)
    end

    def graph_it(statement, output_file)
      ConceptQL::Graph.new(statement, options).graph_it(output_file)
    end
  end
end
