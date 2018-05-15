module ConceptQL
  module Rdbms
    class Generic
      def process(column, value = nil)
        type = Scope::COLUMN_TYPES.fetch(column)
        new_column = case type
        when String, :String
          Sequel.cast_string(value)
        when Date, :Date
          cast_date(value)
        when Float, :Bigint, :Float
          Sequel.cast_numeric(value, type)
        else
          raise "Unexpected type: '#{type.inspect}' for column: '#{column}'"
        end
        new_column.as(column)
      end

      def semi_join(ds, table, *exprs)
        ds = Sequel[ds] if ds.is_a?(Symbol)
        table = Sequel[table] if table.is_a?(Symbol)
        expr = exprs.inject(&:&)
        ds.where(ds.db[table.as(:r)]
          .select(1)
          .where(expr)
          .exists
        )
      end

      def cast_date(date)
        Sequel.cast(date, Date)
      end

      # Impala is teh dumb in that it won't allow columns with constants to
      # be part of the partition of a window function.
      #
      # Meanwhile, the rest of the civilized RDBMS world is fine with it
      #
      # So, by default, return the name of the column and in the Impala adapter
      # we'll return something funky to trick Impala into allowing a constant
      def partition_fix(column, qualifier=nil)
        column
      end
    end
  end
end

