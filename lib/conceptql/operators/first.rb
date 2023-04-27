require_relative 'occurrence'

module ConceptQL
  module Operators
    # Represents a operator that will grab the first occurrence of something
    #
    # The operator treats all streams as a single, large stream.  It partitions
    # that larget stream by person_id, then sorts within those groupings
    # by start_date and then select at most one row per person, regardless
    # of how many different types of streams enter the operator
    #
    # If two rows have the same start_date, the order of their ranking
    # is arbitrary
    #
    # If we ask for the first occurrence of something and a person has no
    # occurrences, this operator returns nothing for that person
    class First < Occurrence
      register __FILE__

      desc "Passes along, per person, the record with the earliest start_date."

      def occurrence
        1
      end
    end
  end
end

