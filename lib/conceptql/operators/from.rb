module ConceptQL
  module Operators
    class From < Operator
      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::Timeless

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
        return @table_name if @table_name
        name = values.first
        if name.is_a?(String)
          table, column = name.split('__', 2)
          if column
            name = Sequel.qualify(table, column)
          else
            name = name.to_sym
          end
        end
        @table_name = name
      end

      def required_columns
        override_columns.keys
      end

      def query_cols
        required_columns
      end

      def override_columns
        cols = (options[:query_cols] || dynamic_columns).map(&:to_sym)
        Hash[cols.zip(cols)]
      end

      def same_table?(table)
        table_name === table
      end
    end
  end
end
