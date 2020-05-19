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
        ds.auto_column(:window_id, Sequel.cast_numeric(nil))
          .auto_column(:uuid, proc { |qualifier| rdbms.uuid(qualifier) })
          .auto_columns(default_columns)
          .auto_column_default(null_columns)
      end

      def default_columns
        cols = Scope::DEFAULT_COLUMNS.keys
        cols.zip(cols).to_h
      end
    end
  end
end
