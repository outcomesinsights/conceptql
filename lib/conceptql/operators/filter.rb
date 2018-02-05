require_relative 'binary_operator_operator'

module ConceptQL
  module Operators
    class Filter < BinaryOperatorOperator
      register __FILE__

      desc 'If a result in the left hand results (LHR) has a corresponding result in the right hand results (RHR) with the same person, criterion_id, and criterion_domain, it is passed through.'
      default_query_columns

      def query(db)
        rhs = right.evaluate(db)
        rhs = rhs.from_self.select_group(*columns)
        query = db.from(Sequel.as(left.evaluate(db), :l))
        query = query
          .left_join(Sequel.as(rhs, :r), join_columns)
          .exclude(Sequel[:r][:criterion_id] => nil)
          .select_all(:l)
        db.from(query)
      end

      def columns
        @columns ||= determine_columns
      end

      def join_columns
        Hash[columns.zip(columns)]
      end

      def determine_columns
        columns = %w(person_id criterion_id criterion_domain)
        columns += %w(start_date end_date) unless options[:ignore_dates]
        columns.map(&:to_sym)
      end
    end
  end
end

