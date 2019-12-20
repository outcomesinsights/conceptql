require_relative "base"

module ConceptQL
  module Operators
    class Projection < Base
      register __FILE__
      allows_one_upstream
      validate_one_upstream
      category "Filter Single Stream"
      basic_type :temporal

      def query(db)
        ds = stream.evaluate(db)
        return ds if scope.output_columns.empty?
        add_columns
        apply_joins(ds)
      end

      def options
        new_opts = {required_columns: scope.query_columns + Array(scope.output_columns)}
        super.merge(new_opts)
      end

      def apply_joins(ds)
        count = 0
        views.reduce(ds.from_self(alias: :og)) do |ds, (table_alias, view)|
          matching = %i[criterion_id criterion_table].each.with_object({}) do |col, h|
            h[Sequel[:og][col]] = Sequel[table_alias][col]
          end
          ds.left_join(view.name, matching, table_alias: table_alias)
        end
      end

      def views
        @views ||= dm.nschema.views_by_column(*scope.output_columns)
          .map
          .with_index { |v, i| ["view#{i}".to_sym, v] }
      end

      def add_columns
        views.each do |table_alias, view|
          cols_to_include = view.columns.map(&:name)
          cols_to_include |= scope.output_columns
          cols_to_include -= %i[criterion_id criterion_table]

          cols_to_include.each do |col|
            columns.add_column(col, Sequel[table_alias][col])
          end
        end
        scope.query_columns.each do |col|
          columns.add_column(col, Sequel[:og][col])
        end
      end
    end
  end
end
