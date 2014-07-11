require_relative 'occurrence'

module ConceptQL
  module Nodes
    # Represents a node that will grab the last occurrence of something
    #
    # The node treats all streams as a single, large stream.  It partitions
    # that larget stream by person_id, then sorts within those groupings
    # by start_date and then select at most one row per person, regardless
    # of how many different types of streams enter the node
    #
    # If two rows have the same start_date, the order of their ranking
    # is arbitrary
    #
    # If we ask for the last occurrence of something and a person has no
    # occurrences, this node returns nothing for that person
    class Last < Occurrence
      def occurrence
        -1
      end
    end
  end
end

