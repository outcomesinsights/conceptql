require_relative "base"

module ConceptQL
  module Operators
    class From < Base
      include ConceptQL::Behaviors::Selectable
      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::Timeless

      register __FILE__
      basic_type :selection
      option :domains, type: Array
      option :query_cols, type: Array
      no_desc
      validate_no_upstreams
      validate_one_argument
      no_default_columns

      def query(db)
        ds = make_selectable(db[table_name])
        apply_known_columns(db, ds)
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
        @table_name ||= get_table_name
      end

      def apply_known_columns(db, ds)
        unless no_db?(db)
          @known_columns = ds.columns
          # Force #output_columns to recompute now that we've updated @known_columns
          @output_columns = nil
        end
        ds.auto_columns(known_columns.zip(known_columns).to_h)
      end

      def get_table_name
        table = column = nil
        name = arguments.first
        case name
        when String
          table, column = name.split('__', 2)
          name = name.to_sym
        when nil
          table, column = *(options.values_at(:table, :column))
        end

        if column
          name = Sequel.qualify(table, column)
        end

        name
      end

      # Watch out for this method
      # We set @output_columns in apply_known_columns
      # So this can sometimes change what it returns :-(
      def output_columns
        @output_columns ||= known_columns - scope.query_columns
      end

      def known_columns
        @known_columns ||= (options[:query_cols] || scope.query_columns).map(&:to_sym)
      end

      def include_uuid?
        super || known_columns.include?(:uuid)
      end
    end
  end
end
