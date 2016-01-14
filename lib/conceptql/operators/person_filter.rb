require_relative 'binary_operator_operator'

module ConceptQL
  module Operators
    class PersonFilter < BinaryOperatorOperator
      register __FILE__, :omopv4

      desc 'Only passes through a result from the LHR if the person appears in the RHR.'
      def query(db)
        db.from(left.evaluate(db))
          .where(person_id: right.evaluate(db).select_group(:person_id))
      end
    end
  end
end
