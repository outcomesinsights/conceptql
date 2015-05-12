require_relative 'pass_thru'

module ConceptQL
  module Operators
    class From < Operator
      def query(db)
        db.from(values.first)
      end

      def types
        values[1..99].compact
      end
    end
  end
end
