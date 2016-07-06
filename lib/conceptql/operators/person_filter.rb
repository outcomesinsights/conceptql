require_relative 'binary_operator_operator'

module ConceptQL
  module Operators
    class PersonFilter < BinaryOperatorOperator
      register __FILE__

      desc 'If a result in the left hand results (LHR) matches a person in the right hand results (RHR), it is passed through.'
      default_query_columns

      def query(db)
        db.from(left.evaluate(db))
          .where(person_id: right.evaluate(db).select_group(:person_id))
      end
    end
  end
end
