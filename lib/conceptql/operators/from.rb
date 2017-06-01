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
        db.from(table_name)
      end

      def domains(db)
        doms = options[:domains]
        if doms.nil? || doms.empty?
          if dm.schema.has_key?(table)
            [table]
          else
            [:invalid]
          end
        else
          doms.map(&:to_sym)
        end
      end

      def table_name
        values.first.to_sym rescue nil
      end

      def query_cols
        cols = options[:query_cols]
        if cols.nil? || cols.empty?
          cols = table_columns(table) rescue dynamic_columns
        end
        cols
      end
    end
  end
end
