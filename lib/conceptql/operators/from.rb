require_relative 'pass_thru'

module ConceptQL
  module Operators
    class From < Operator
      register __FILE__, :omopv4
      basic_type :selection
      no_desc
      validate_no_upstreams
      validate_one_argument

      def query_cols
        table_columns(values.first.to_sym) rescue ConceptQL::Operators::SELECTED_COLUMNS
      end

      def query(db)
        db.refresh(values.first.to_sym) if db.respond_to?(:refresh)
        db.from(values.first.to_sym)
      end

      def domains
        domains = values[1..99].compact
        domains.empty? ? [:invalid] : domains.map(&:to_sym)
      end

      def domain
        values.first.to_sym
      end
    end
  end
end
