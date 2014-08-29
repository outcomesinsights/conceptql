require_relative 'binary_operator_node'

module ConceptQL
  module Nodes
    # Base class for all temporal nodes
    #
    # Subclasses must implement the where_clause method which should probably return
    # a proc that can be executed as a Sequel "virtual row" e.g.
    # Proc.new { l.end_date < r.start_date }
    class TemporalNode < BinaryOperatorNode
      def query(db)
        db.from(db.from(left_stream(db))
                  .join(right_stream(db), l__person_id: :r__person_id)
                  .where(where_clause)
                  .select_all(:l))
      end

      def inclusive?
        options[:inclusive]
      end

      def left_stream(db)
        Sequel.expr(left.evaluate(db)).as(:l)
      end

      def right_stream(db)
        Sequel.expr(right.evaluate(db)).as(:r)
      end
    end
  end
end


