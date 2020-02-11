require_relative "base"

module ConceptQL
  module Operators
    class Projection < Base
      include ConceptQL::Behaviors::Selectable

      register __FILE__

      no_desc
      allows_one_upstream
      validate_one_upstream
      category "Filter Single Stream"
      basic_type :temporal

      def query(db)
        ds = stream.evaluate(db)
        return ds if scope.output_columns.empty?
        apply_joins(ds)
      end

      def required_columns
        (scope.query_columns | scope.output_columns) - projection_columns
      end

      def annotate(db, opts = {})
        stream.annotate(db, opts)
      end

      def view_columns
        out_columns + join_ids
      end

      def join_ids
        %i[criterion_id criterion_table]
      end

      def out_columns
        (scope.output_columns || []) - %i[uuid]
      end

      def apply_joins(ds)
        db = ds.db
        ds = ds.from_self(alias: :proj)

        mapped_views = views.map do |view|
          cols = view.columns.map(&:name) & view_columns
          db[view.name]
            .auto_columns(cols.zip(cols).to_h)
            .auto_column_default(null_columns)
            .auto_select(required_columns: view_columns)
        end

        columns = out_columns.map { |c| [c, []] }.to_h

        mapped_views.each.with_index(1) do |view, i|
          view_alias = "view_#{i}".to_sym
          matching = join_ids.each.with_object({}) do |col, h|
            h[Sequel[:proj][col]] = Sequel[view_alias][col]
          end

          ds = ds.left_join(view, matching, table_alias: view_alias)
          columns.transform_values! { |v| v << view_alias }
        end

        columns = columns
          .select { |name, views| !views.blank?}
          .map do |col_name, views|
          cols = views.map { |v| Sequel[v][col_name] }
          cols = if cols.length > 1
                   Sequel.function(:coalesce, *cols) 
                 else
                   cols.pop
                 end
          [col_name, cols]
        end.to_h

        scope.query_columns.each do |col|
          ds = ds.auto_column(col, Sequel[:proj][col])
        end

        ds = ds.auto_columns(columns)

        if scope.output_columns.include?(:uuid)
          ds = ds.require_column(:uuid)
        end

        ds.auto_columns(upstream_auto_columns(ds))
      end

      def views
        @views ||= dm.nschema.views_by_column(*scope.output_columns).compact
      end

      def projection_columns
        views.map(&:columns).flatten - possibly_upstream_columns
      end

      def possibly_upstream_columns
        %i[lab_value_as_number admission_date discharge_date]
      end

      def upstream_auto_columns(ds)
        possibly_upstream_columns.map do |col|
          [col, Sequel.function(:coalesce, Sequel[:proj][col], ds.opts[:auto_columns][col])]
        end.to_h
      end

      def add_columns(ds)
        views.each do |table_alias, view|
          cols_to_include = view.columns.map(&:name)
          cols_to_include &= scope.output_columns
          cols_to_include -= %i[criterion_id criterion_table]

          cols_to_include.each do |col|
            ds = ds.auto_column(col, Sequel[table_alias][col])
          end
        end
        ds.auto_columns(upstream_auto_columns(ds))
      end
    end
  end
end
