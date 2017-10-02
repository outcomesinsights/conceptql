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
          if dm.schema.has_key?(table_name)
            [table_name]
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

      def requried_columns
        override_columns.keys
      end

      def override_columns
        cols = (options[:query_cols] || dynamic_columns).map(&:to_sym)
        Hash[cols.zip(cols)]
      end
    end
  end
end
