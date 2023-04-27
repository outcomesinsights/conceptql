require_relative 'binary_operator_operator'

module ConceptQL
  module Operators
    class PersonFilter < BinaryOperatorOperator
      register __FILE__

      desc 'If a record in the left hand records (LHR) matches a person in the right hand records (RHR), it is passed through.'
      default_query_columns

      def query(db)
        db.from(left.evaluate(db))
          .where(person_id: right.evaluate(db).from_self.select_group(:person_id))
      end
    end
  end
end
