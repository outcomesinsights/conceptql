require_relative 'node'

module ConceptQL
  module Nodes
    class Visit < Node
      def types
        [:visit_occurrence]
      end
    end
  end
end
