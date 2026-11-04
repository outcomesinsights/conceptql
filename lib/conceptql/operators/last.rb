# frozen_string_literal: true

require_relative "occurrence"

module ConceptQL
  module Operators
    # Represents a operator that will grab the last occurrence of something
    #
    # The operator takes exactly one upstream. It partitions the records of
    # that upstream by person_id, sorts the records of each person by
    # start_date, and selects at most one row per person, even when the
    # upstream mixes records from several criterion tables
    #
    # If two rows have the same start_date, the order of their ranking
    # is arbitrary
    #
    # If we ask for the last occurrence of something and a person has no
    # occurrences, this operator returns nothing for that person
    class Last < Occurrence
      register __FILE__

      desc "For each person, passes along the record with the most recent start_date."

      returns "One record per person: the upstream record with the latest start_date. " \
              "When several records have that start_date, the one with the highest criterion_id."

      option_meaning :group_by_date,
                     "Treats the records of a person on one start_date as one occurrence. " \
                     "It does not change the result of last, which passes along one record of the latest date either way."

      example "For each patient, select the Condition that represents the last occurrence of an MI",
              [ "last", [ "icd9", "412" ] ]

      # With either option, Occurrence's timed query returns every upstream
      # row instead of one row per person
      unsupported_options :at_least, :within

      def occurrence
        -1
      end

      # A non-blank at_least or within fails validation, but the statement
      # still builds SQL. That SQL stays the plain query, not the timed one.
      def timed?
        false
      end
    end
  end
end
