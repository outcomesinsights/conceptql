require_relative 'pass_thru'

module ConceptQL
  module Operators
    class From < Operator
      register __FILE__, :omopv4
      validate_no_upstreams
      validate_one_argument

      def query_cols
        table_columns(values.first.to_sym) rescue ConceptQL::Operators::SELECTED_COLUMNS
      end

      def query(db)
        db.from(values.first)
      end

      def types
        types = values[1..99].compact
        types.empty? ? [:invalid] : types.map(&:to_sym)
      end
    end
  end
end
