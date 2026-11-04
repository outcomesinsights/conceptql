# frozen_string_literal: true

require_relative "occurrence"

module ConceptQL
  module Operators
    # Represents a operator that will grab the first occurrence of something
    #
    # The operator takes exactly one upstream. It partitions the records of
    # that upstream by person_id, sorts the records of each person by
    # start_date, and selects at most one row per person, even when the
    # upstream mixes records from several criterion tables
    #
    # If two rows have the same start_date, the row with the lowest
    # criterion_id comes first. criterion_id is unique within one
    # criterion_table, so only rows from two different tables with the same
    # id and start_date still rank in arbitrary order
    #
    # If we ask for the first occurrence of something and a person has no
    # occurrences, this operator returns nothing for that person
    class First < Occurrence
      register __FILE__

      desc "For each person, passes along the record with the earliest start_date."

      returns "One record per person: the upstream record with the earliest start_date. " \
              "When several records have that start_date, the one with the lowest criterion_id."

      example "For each patient, select the Condition that represents the first occurrence of an MI",
              [ "first", [ "icd9", "412" ] ]

      # With at_least or within, Occurrence's timed query returns every
      # upstream row instead of one row per person. group_by_date does not
      # change the result, because first passes along one record of the
      # earliest date either way (seed conceptql-ufn).
      unsupported_options :at_least, :within, :group_by_date

      def occurrence
        1
      end

      # A non-blank at_least or within fails validation, but the statement
      # still builds SQL. That SQL stays the plain query, not the timed one.
      def timed?
        false
      end
    end
  end
end
