module ConceptQL
  module Operators
    class From < Operator
      register __FILE__
      basic_type :selection
      no_desc
      option :domains, type: Array
      option :query_cols, type: Array
      validate_no_upstreams
      validate_one_argument

      def query(db)
        db.from(table)
      end

      def domains
        domains = options[:domains]
        if domains.nil? || domains.empty?
          if TABLE_COLUMNS.has_key?(table)
            [table]
          else
            [:invalid]
          end
        else
          domains.map(&:to_sym)
        end
      end

      def table
        values.first.to_sym
      end

      def query_cols
        cols = options[:query_cols]
        if cols.nil? || cols.empty?
          cols = table_columns(table) rescue dynamic_columns
        end
        cols#.tap { |o| puts "QUERY COLS"; p o }
      end
    end
  end
end
