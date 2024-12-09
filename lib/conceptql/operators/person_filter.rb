# frozen_string_literal: true

require_relative 'binary_operator_operator'

module ConceptQL
  module Operators
    class PersonFilter < BinaryOperatorOperator
      register __FILE__

      desc 'Passes along left hand records with a corresponding person_id in the right hand records.'
      default_query_columns

      def query(db)
        db.from(left.evaluate(db))
          .where(person_id: right.evaluate(db).from_self.select_group(:person_id))
      end
    end
  end
end
