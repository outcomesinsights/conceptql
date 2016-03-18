require_relative 'binary_operator_operator'

module ConceptQL
  module Operators
    class Except < BinaryOperatorOperator
      register __FILE__, :omopv4

      desc 'If a LHR result appears in the RHR result, it is removed from the output result set.'
      default_query_columns

      def query(db)
        if ignore_dates?
          query = db.from(Sequel.as(left.evaluate(db), :l))
            .left_join(Sequel.as(right.evaluate(db), :r), l__criterion_id: :r__criterion_id, l__criterion_domain: :r__criterion_domain)
            .where(r__criterion_id: nil)
            .select_all(:l)
          db.from(query)
        else
          lquery = left.evaluate(db)
          rquery = right.evaluate(db)

          # Set columns so that impala's EXCEPT emulation doesn't use a query to determine them
          lquery.instance_variable_set(:@columns, SELECTED_COLUMNS)
          rquery.instance_variable_set(:@columns, SELECTED_COLUMNS)

          lquery.except(rquery)
        end
      end

      private

      def ignore_dates?
        options[:ignore_dates]
      end
    end
  end
end
