module ConceptQL
  module Rdbms
    class Generic
      attr_reader :nodifier

      def initialize(nodifier)
        @nodifier = nodifier
      end

      def scope
        nodifier.scope
      end

      def create_options
        {}
      end

      def drop_options
        {}
      end

      def join_options
        {}
      end

      def post_create(db, table_name)
        # Do nothing
      end

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
        ds.from_self(alias: :l).where(ds.db[table.as(:r)]
          .select(1)
          .where(expr)
          .exists
        ).from_self
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

      def uuid
        uuid_items
          .zip([Sequel.cast_string('/')] * (uuid_items.length - 1))
          .flatten
          .compact
          .inject(:+)
      end

      def uuid_items
        %w(person_id criterion_id criterion_table start_date).map do |column|
          Sequel.cast_string(column.to_sym)
        end
      end
    end
  end
end

