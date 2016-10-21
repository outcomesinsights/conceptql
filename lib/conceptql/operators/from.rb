module ConceptQL
  module Operators
    class From < Operator
      register __FILE__
      basic_type :selection
      no_desc
      validate_no_upstreams
      validate_one_argument

      def query_cols
        table_columns(values.first.to_sym) rescue dynamic_columns
      end

      def query(db)
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
