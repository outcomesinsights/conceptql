require_relative 'binary_operator_operator'

module ConceptQL
  module Operators
    class Except < BinaryOperatorOperator
      register __FILE__

      desc 'If a result in the left hand results (LHR) appears in the right hand results (RHR), it is removed from the output result set.'
      default_query_columns

      def query(db)
        cols_to_compare = [
          :criterion_id,
          :criterion_table,
        ]
        cols_to_compare += [:start_date, :end_date] unless ignore_dates?
        join_cols = cols_to_compare.zip(cols_to_compare).to_h

        query = db.from(Sequel.as(left.evaluate(db), :l))
          .left_join(Sequel.as(right.evaluate(db), :r), join_cols)
          .where(Sequel[:r][:criterion_id] => nil)
          .select_all(:l)
        db.from(query)
      end

      private

      def ignore_dates?
        options[:ignore_dates]
      end
    end
  end
end
