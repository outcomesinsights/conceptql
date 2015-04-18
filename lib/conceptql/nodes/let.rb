require_relative 'node'
require_relative '../query'

module ConceptQL
  module Nodes
    class Let < Node
      desc 'Used to create a scope for Define/Recall operators.'
      allows_many_children

      def query(db)
        evaluated(db).last
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

      private
      def evaluated(db)
        @evaluated ||= perform_evaluations(db)
      end

      def perform_evaluations(db)
        children.map do |child|
          child.evaluate(db)
        end
      end
    end
  end
end

