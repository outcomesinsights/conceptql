require_relative 'node'

module ConceptQL
  module Nodes
    # Represents a node that will grab the Nth occurrence of something
    #
    # Specify occurrences as integers, excluding O
    # 1 => first
    # 2 => second
    # ...
    # -1 => last
    # -2 => second-to-last
    #
    # The node treats all streams as a single, large stream.  It partitions
    # that larget stream by person_id, then sorts within those groupings
    # by start_date and then select at most one row per person, regardless
    # of how many different types of streams enter the node
    #
    # If two rows have the same start_date, the order of their ranking
    # is arbitrary
    #
    # If we ask for the second occurrence of something and a person has only one
    # occurrence, this node returns nothing for that person
    class Occurrence < Node
      def query(db)
        db.from(db.from(stream.evaluate(db))
          .select_append { |o| o.row_number(:over, partition: :person_id, order: ordered_columns){}.as(:rn) })
          .where(rn: occurrence.abs)
      end

      def occurrence
        @occurrence ||= arguments.first
      end

      private
      def asc_or_desc
        occurrence < 0 ? :desc : :asc
      end

      def ordered_columns
        ordered_columns = [Sequel.send(asc_or_desc, :start_date)]
        ordered_columns += [:criterion_type, :criterion_id]
      end
    end
  end
end

