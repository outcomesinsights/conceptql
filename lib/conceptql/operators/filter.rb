# frozen_string_literal: true

require_relative "binary_operator_operator"

module ConceptQL
  module Operators
    class Filter < BinaryOperatorOperator
      register __FILE__
      effects :keep

      desc "Keeps each left-hand result that also appears in the right-hand stream. Two results are the same when they have the same person_id, criterion_id, criterion_table, criterion_domain, start_date and end_date."
      returns "The left-hand results that have a right-hand result with the same person_id, criterion_id, criterion_table, criterion_domain, start_date and end_date. The right-hand results are not returned."
      option_meaning :right, "The right-hand stream. The operator keeps each left-hand result that is also in this stream, and does not pass these results on."

      example "MIs that are a patient's first diagnosis of MI or diabetes",
              [ "filter", { left: [ "icd9", "412" ], right: [ "first", [ "union", [ "icd9", "412" ], [ "icd9", "250.01" ] ] ] } ]
      default_query_columns

      # An `as` option would cast both streams before the comparison. Filter
      # has no such option, and a statement that sets one fails validation
      # instead of running as a plain filter (bead conceptql-8ac).
      unsupported_options :as

      def query(db)
        rhs = right.evaluate(db)
        rhs = rhs.from_self.select_group(*columns)
        query = db.from(Sequel.as(left.evaluate(db), :l))
        query = semi_or_inner_join(query, rhs, join_columns)
        db.from(query)
      end

      def columns
        @columns ||= determine_columns
      end

      def join_columns
        columns.map { |c| [ Sequel[:l][c], Sequel[:r][c] ] }
      end

      # criterion_id is an id within its criterion_table, so two records from
      # different tables can share one. Without criterion_table, a condition
      # from observations matched a hospitalization from collections (both
      # have the condition_occurrence domain) whenever their ids were equal
      # (bead conceptql-fun).
      def determine_columns
        columns = %w[person_id criterion_id criterion_table criterion_domain]
        columns += %w[start_date end_date] unless options[:ignore_dates]
        columns.map(&:to_sym)
      end
    end
  end
end
