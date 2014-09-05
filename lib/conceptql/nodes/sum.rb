require_relative 'pass_thru'

module ConceptQL
  module Nodes
    class Sum < PassThru
      def query(db)
        db.from(unioned(db))
          .select_group(*(COLUMNS - [:start_date, :end_date, :criterion_id, :value_as_numeric]))
          .select_append(Sequel.lit('?', 0).as(:criterion_id))
          .select_append{ min(start_date).as(:start_date) }
          .select_append{ max(end_date).as(:end_date) }
          .select_append{sum(value_as_numeric).as(:value_as_numeric)}
          .from_self
      end

      def unioned(db)
        children.map { |c| c.evaluate(db) }.inject do |uni, q|
          uni.union(q)
        end
      end
    end
  end
end

