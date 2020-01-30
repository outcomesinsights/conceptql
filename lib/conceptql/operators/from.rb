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

      def query(db)
        ds = make_selectable(db[table_name])
        ds = ds.auto_column(:uuid, :uuid) if known_columns.include?(:uuid)
        apply_known_columns(ds)
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

      def apply_known_columns(ds)
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

      def output_columns
        known_columns - scope.query_columns
      end

      def known_columns
        (options[:query_cols] || scope.query_columns).map(&:to_sym)
      end

      def include_uuid?
        super || known_columns.include?(:uuid)
      end
    end
  end
end
