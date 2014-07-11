require_relative 'binary_operator_node'

module ConceptQL
  module Nodes
    class Except < BinaryOperatorNode
      def query(db)
        left.evaluate(db).except(right.evaluate(db))
      end
    end
  end
end
