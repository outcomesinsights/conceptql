require_relative 'pass_thru'

module ConceptQL
  module Nodes
    class Count < PassThru
      def query(db)
        db.from(unioned(db))
          .group(*COLUMNS)
          .select(*(COLUMNS - [:value_as_numeric]))
          .select_append{count(1).as(:value_as_numeric)}
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


