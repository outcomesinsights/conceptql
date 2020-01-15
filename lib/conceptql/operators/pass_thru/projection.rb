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
        ds = add_columns(ds.from_self(alias: :proj))
        apply_joins(ds)
      end

      def required_columns
        (scope.query_columns | scope.output_columns) - projection_columns
      end

      def apply_joins(ds)
        count = 0
        views.reduce(ds) do |ds, (table_alias, view)|
          matching = %i[criterion_id criterion_table].each.with_object({}) do |col, h|
            h[Sequel[:proj][col]] = Sequel[table_alias][col]
          end
          ds.left_join(view.name, matching, table_alias: table_alias)
        end
      end

      def views
        @views ||= dm.nschema.views_by_column(*scope.output_columns)
          .compact
          .map
          .with_index { |v, i| ["view#{i}".to_sym, v] }
      end

      def projection_columns
        views.map(&:last).map(&:columns).flatten
      end

      def add_columns(ds)
        scope.query_columns.each do |col|
          ds = ds.auto_column(col, Sequel[:proj][col])
        end
        if scope.output_columns.include?(:uuid)
          ds = ds.require_column(:uuid)
        end
        views.each do |table_alias, view|
          cols_to_include = view.columns.map(&:name)
          cols_to_include &= scope.output_columns
          cols_to_include -= %i[criterion_id criterion_table]

          cols_to_include.each do |col|
            ds = ds.auto_column(col, Sequel[table_alias][col])
          end
        end
        ds
      end
    end
  end
end
