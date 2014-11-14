require_relative 'binary_operator_node'

module ConceptQL
  module Nodes
    class Filter < BinaryOperatorNode
      def query(db)
        rhs = right.evaluate(db)
        rhs = rhs.select_group(:criterion_id, :criterion_type)
        query = db.from(Sequel.as(left.evaluate(db), :l))
        query = query
          .left_join(Sequel.as(rhs, :r), l__criterion_id: :r__criterion_id, l__criterion_type: :r__criterion_type)
          .exclude(r__criterion_id: nil)
          .select_all(:l)
        db.from(query)
      end
    end
  end
end

