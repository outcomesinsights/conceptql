require_relative "base"

module ConceptQL
  module Operators
    class Projection < Base
      register __FILE__
      allows_one_upstream
      validate_one_upstream
      category "Filter Single Stream"
      basic_type :temporal
      validate_at_least_one_argument

      def query(db)
        q = upstream.evaluate(db)
        tables_and_columns.inject(q) do |q, (table, columns)|
        end
      end

      def tables_and_columns
        @tables_and_columns ||= arguments.each.with_object(Hash.new([])) do |col, h|
          table = table_for_column(col)
          h[table] << col
        end
      end

      def table_for_column(col)
      end
    end
  end
end
