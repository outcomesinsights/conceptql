module ConceptQL
  module Rdbms
    class Generic
      def days_between(from_column, to_column)
        cast_date(to_column) - cast_date(from_column)
      end

      def least_function
        :least
      end

      def greatest_function
        :greatest
      end

      def process(column, value = nil)
        cast_it(column, value).as(column)
      end

      def cast_it(column, value = nil)
        type = Scope::COLUMN_TYPES.fetch(column)

        new_column = case type
        when String, :String, "String"
          Sequel.cast_string(value)
        when Date, :Date
          cast_date(value)
        when Float, :Bigint, :Float
          Sequel.cast_numeric(value, type)
        else
          raise "Unexpected type: '#{type.inspect}' for column: '#{column}'"
        end

        new_column
      end

      def cast_null(columns)
        columns.map { |c| process(c) }
      end

      def preferred_formatter
        nil
      end

      def semi_join(ds, table, *exprs)
        ds = Sequel[ds] if ds.is_a?(Symbol)
        table = Sequel[table] if table.is_a?(Symbol)
        expr = exprs.inject(&:&)
        ds.from_self(alias: :l).where(
          ds.db[table.as(:r)]
            .select(1)
            .where(expr)
            .exists
        )
      end

      def cast_date(date)
        Sequel.cast(date, Date)
      end

      def uuid(qualifier = nil)
        uuid_items(qualifier)
          .zip([Sequel.cast_string('/')] * (uuid_items.length - 1))
          .flatten
          .compact
          .inject(:+)
      end

      def uuid_items(qualifier = nil)
        qualifier ||= Sequel
        uuid_columns.map do |column|
          Sequel.cast_string(qualifier[column])
        end
      end

      def uuid_columns
        %i[person_id criterion_id criterion_table start_date end_date]
      end
    end
  end
end

