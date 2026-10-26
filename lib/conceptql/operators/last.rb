# frozen_string_literal: true

require_relative "occurrence"

module ConceptQL
  module Operators
    # Represents a operator that will grab the last occurrence of something
    #
    # The operator treats all streams as a single, large stream.  It partitions
    # that larget stream by person_id, then sorts within those groupings
    # by start_date and then select at most one row per person, regardless
    # of how many different types of streams enter the operator
    #
    # If two rows have the same start_date, the order of their ranking
    # is arbitrary
    #
    # If we ask for the last occurrence of something and a person has no
    # occurrences, this operator returns nothing for that person
    class Last < Occurrence
      register __FILE__

      desc "For each person, passes along the record with the most recent start_date."

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
