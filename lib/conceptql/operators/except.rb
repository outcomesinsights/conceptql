require_relative 'binary_operator_node'

module ConceptQL
  module Operators
    class Except < BinaryOperatorNode
      desc 'If a LHR result appears in the RHR result, it is removed from the output result set.'
      category 'Set Logic'

      def query(db)
        if ignore_dates?
          query = db.from(Sequel.as(left.evaluate(db), :l))
            .left_join(Sequel.as(right.evaluate(db), :r), l__criterion_id: :r__criterion_id, l__criterion_type: :r__criterion_type)
            .where(r__criterion_id: nil)
            .select_all(:l)
          db.from(query)
        else
          left.evaluate(db).except(right.evaluate(db))
        end
      end

      private

      def ignore_dates?
        options[:ignore_dates]
      end
    end
  end
end
