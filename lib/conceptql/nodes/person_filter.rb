require_relative 'binary_operator_node'

module ConceptQL
  module Nodes
    class PersonFilter < BinaryOperatorNode
      def query(db)
        db.from(left.evaluate(db))
          .where(person_id: right.evaluate(db).select_group(:person_id))
      end
    end
  end
end
