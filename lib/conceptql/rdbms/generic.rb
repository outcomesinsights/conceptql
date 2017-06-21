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

      def cast_date(date)
        Sequel.cast(date, Date)
      end
    end
  end
end

