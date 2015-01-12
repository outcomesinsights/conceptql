require_relative 'node'
require_relative '../query'

module ConceptQL
  module Nodes
    class Let < Node
      def query(db)
        evaluated = children.map do |child|
          child.evaluate(db)
        end
        evaluated.last
      end

      def types
        children.last.types
      end

      def graph_it(g, db)
        cluster_name = "cluster_#{node_name}"
        linkable = nil
        g.send(cluster_name) do |sub|
          linkable = children.reverse.map do |child|
            child.graph_it(sub, db)
          end.first
          sub[label: display_name, color: 'black']
        end
        @__graph_node = linkable
      end
    end
  end
end

