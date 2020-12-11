module ConceptQL
  module Behaviors
    module Selectable
      module ClassMethods
        def no_default_columns
          define_method(:default_columns) { Hash.new }
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      def null_columns
        proc do |hash, key|
          hash[key.to_sym] = cast_column(key)
        end
      end

      def make_selectable(ds)
        ds = ds.auto_column(:window_id, Sequel.cast_numeric(nil))
          .auto_column(:uuid, proc { |qualifier| rdbms.uuid(qualifier) })
          .auto_columns(default_columns)
          .auto_column_default(null_columns)
          .auto_select(alias: :cc, required_columns: required_columns)

        ds.auto_column(:file_provenance_type, Sequel[:pjv][:file_provenance_type])
          .auto_column(:code_provenance_type, Sequel[:pjv][:code_provenance_type])
          .auto_column(:admission_date, Sequel[:ajv][:admission_date])
          .auto_column(:discharge_date, Sequel[:ajv][:discharge_date])
          #.left_join(:provenance_join_view_v1, {Sequel[:pjv][:criterion_id] => Sequel[:cc][:criterion_id]}, table_alias: :pjv)
          #.left_join(:admission_join_view_v1, {Sequel[:ajv][:criterion_id] => Sequel[:cc][:criterion_id]}, table_alias: :ajv)
      end

      def default_columns
        cols = Scope::DEFAULT_COLUMNS.keys
        cols.zip(cols).to_h
      end
    end
  end
end
