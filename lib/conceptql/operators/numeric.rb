# frozen_string_literal: true

require_relative 'pass_thru'

module ConceptQL
  module Operators
    # Represents a operator that will either:
    # - create a value_as_number value for every person in the database
    # - change the value_as_number value for every every record passed in
    #   - either to a number
    #   - or a value from a column in the origin row
    #
    # Accepts two params:
    # - Either a number value or a symbol representing a column name
    # - An optional stream
    class Numeric < PassThru
      register __FILE__

      desc <<~EOF
        Represents an operator that will either:
        - Create a value_as_number value for every person in the database
        - Change the value_as_number value for every record passed in
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

      def query(db)
        stream.nil? ? as_criterion(db) : with_kids(db)
      end

      def domains(db)
        stream.nil? ? [:person] : super
      end

      private

      def with_kids(db)
        dm.selectify(db.from(stream.evaluate(db)), replace: { value_as_number: first_argument })
      end

      def as_criterion(db)
        dm.selectify(db.from(dm.table_by_domain(:person)), domain: :person,
                                                           replace: { value_as_number: first_argument })
      end

      def first_argument
        value = arguments.first.to_s.strip
        value = nil if value.blank?
        if !value || is_a_number?(value)
          Sequel.cast_numeric(value, Float)
        else
          Sequel.identifier(value)
        end
      end

      def is_a_number?(value)
        value =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/
      end
    end
  end
end
