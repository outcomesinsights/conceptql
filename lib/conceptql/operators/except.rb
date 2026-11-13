# frozen_string_literal: true

require_relative "binary_operator_operator"

module ConceptQL
  module Operators
    class Except < BinaryOperatorOperator
      register __FILE__
      effects :keep

      desc "Removes each left-hand result that also appears in the right-hand stream. Two results are the same when they have the same criterion_table, criterion_id, start_date and end_date."
      returns "The left-hand results that have no right-hand result with the same criterion_table, criterion_id, start_date and end_date. A left-hand result whose table has no right-hand result passes through unchanged. The right-hand results are not returned."
      option_meaning :right, "The right-hand stream. The operator removes each left-hand result that is also in this stream, and does not pass these results on."

      example "All males who are not white",
              [ "except", { left: [ "gender", "male" ], right: [ "race", "white" ] } ]
      example "All Conditions that are MI",
              [ "except", { left: [ "icd9", "412" ], right: [ "cpt", "99214" ] } ]
      example "Passes two types downstream: Conditions that are MI (unaffected by the right-hand stream) and People that are Male but not White",
              [ "except", { left: [ "union", [ "icd9", "412" ], [ "gender", "Male" ] ], right: [ "race", "White" ] } ]
      default_query_columns

      # An `as` option would cast both streams before the comparison. Except
      # has no such option, and a statement that sets one fails validation
      # instead of running as a plain except (bead conceptql-dlq).
      unsupported_options :as

      def query(db)
        cols_to_compare = %i[
          criterion_id
          criterion_table
        ]
        cols_to_compare += %i[start_date end_date] unless ignore_dates?
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
