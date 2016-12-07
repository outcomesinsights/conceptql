require_relative 'pass_thru'

module ConceptQL
  module Operators
    # Represents a operator that will either:
    # - create a value_as_number value for every person in the database
    # - change the value_as_number value for every every result passed in
    #   - either to a number
    #   - or a value from a column in the origin row
    #
    # Accepts two params:
    # - Either a number value or a symbol representing a column name
    # - An optional stream
    class Numeric < PassThru
      register __FILE__

      desc <<-EOF
Represents an operator that will either:
- Create a value_as_number value for every person in the database
- Change the value_as_number value for every result passed in
  - Either to a number
  - Or a value from a column in the origin row

Accepts two params:
- Either a number value or a symbol representing a column name
- An optional stream
      EOF
      argument :value, type: :float
      allows_one_upstream
      validate_at_most_one_upstream
      validate_one_argument
      default_query_columns
      require_column :value_as_number

      def query_cols
        (stream.nil? ? table_cols(:person) : dynamic_columns - [:value_as_number]) + [:value_as_number]
      end

      def query(db)
        stream.nil? ? as_criterion(db) : with_kids(db)
      end

      def domains(db)
        stream.nil? ? [:person] : super
      end

      private
      def with_kids(db)
        db.from(stream.evaluate(db))
          .select(*(dynamic_columns - [:value_as_number]))
          .select_append(first_argument.cast(Float).as(:value_as_number))
          .from_self
      end

      def as_criterion(db)
        db.from(select_it(db.from(:person).clone(force_columns: table_columns(:person)), :person))
          .select(*(dynamic_columns - [:value_as_number]))
          .select_append(first_argument.cast(Float).as(:value_as_number))
          .from_self
      end

      def first_argument
        case arguments.first
        when String
          Sequel.identifier(arguments.first)
        else
          Sequel.expr(arguments.first)
        end
      end
    end
  end
end

