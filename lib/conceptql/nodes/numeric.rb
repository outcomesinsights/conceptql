require_relative 'pass_thru'

module ConceptQL
  module Nodes
    # Represents a node that will either:
    # - create a value_as_numeric value for every person in the database
    # - change the value_as_numeric value for every every result passed in
    #   - either to a numeric
    #   - or a value from a column in the origin row
    #
    # Accepts two params:
    # - Either a numeric value or a symbol representing a column name
    # - An optional stream
    class Numeric < PassThru
      def query(db)
        stream.nil? ? as_criterion(db) : with_kids(db)
      end

      def types
        stream.nil? ? [:person] : super
      end

      private
      def with_kids(db)
        db.from(stream.evaluate(db))
          .select(*(COLUMNS - [:value_as_numeric]))
          .select_append(Sequel.lit('?', arguments.first).cast(Float).as(:value_as_numeric))
          .from_self
      end

      def as_criterion(db)
        db.from(select_it(db.from(:person), :person))
          .select(*(COLUMNS - [:value_as_numeric]))
          .select_append(Sequel.lit('?', arguments.first).cast(Float).as(:value_as_numeric))
          .from_self
      end
    end
  end
end

