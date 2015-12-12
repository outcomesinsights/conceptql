require_relative 'pass_thru'

module ConceptQL
  module Operators
    # Mimics using a variable that has been set via "define" operator
    #
    # The idea is that a concept might be very complex and it helps to break
    # that complex concept into a set of sub-concepts to better understand it.
    #
    # This operator will look for a sub-concept that has been created through the
    # "define" operator and will fetch the results cached in the corresponding table
    class Recall < Operator
      register __FILE__

      desc <<-EOF
Recalls a set of named results that were previously stored using the Define operator.
Must be surrounded by the same Let operator as surrounds the corresponding Define operator.
      EOF
      argument :name, type: :string
      category 'Variable Assignment'

      def query(db)
        scope.from(db, source)
      end

      def columns(query, local_type)
        COLUMNS
      end

      def types
        scope.types(source)
      end

      def source
        arguments.first
      end
    end
  end
end

