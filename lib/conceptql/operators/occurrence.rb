require_relative 'operator'

module ConceptQL
  module Operators
    # Represents a operator that will grab the Nth occurrence of something
    #
    # Specify occurrences as integers, excluding O
    # 1 => first
    # 2 => second
    # ...
    # -1 => last
    # -2 => second-to-last
    #
    # The operator treats all streams as a single, large stream.  It partitions
    # that larget stream by person_id, then sorts within those groupings
    # by start_date and then select at most one row per person, regardless
    # of how many different types of streams enter the operator
    #
    # If two rows have the same start_date, the order of their ranking
    # is arbitrary
    #
    # If we ask for the second occurrence of something and a person has only one
    # occurrence, this operator returns nothing for that person
    class Occurrence < Operator
      register __FILE__, :omopv4

      preferred_name 'Nth Occurrence'

      desc <<-EOF
Groups all results by person, then orders by start_date and finds the nth occurrence (can be positive or negative).
1 => first
2 => second
...
-1 => last
-2 => second-to-last

If two results have the same start_date, their relative order
is arbitrary.

If we ask for the second occurrence of something and a person has only one
occurrence, this operator returns nothing for that person.
      EOF

      argument :occurrence, type: :integer
      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_at_least_one_upstream
      option :unique, type: :boolean

      def query_cols
        SELECTED_COLUMNS + [:rn]
      end

      def query(db)
        cte_name = scope.add_extra_cte(:occurrences,
            all_or_uniquified_results(db)
              .from_self
              .select_append { |o| o.row_number(:over, partition: :person_id, order: ordered_columns){}.as(:rn) })
        db[cte_name]
          .where(rn: occurrence.abs)
      end

      def occurrence
        @occurrence ||= arguments.first
      end

      private

      def validate(db)
        super
        if self.class == Occurrence
          validate_one_argument
        else
          validate_no_arguments
        end
      end

      def asc_or_desc
        occurrence < 0 ? :desc : :asc
      end

      def ordered_columns
        ordered_columns = [Sequel.send(asc_or_desc, :start_date)]
        ordered_columns += [:criterion_id]
      end

      def uniquify_partition_columns
        SELECTED_COLUMNS - [:criterion_id, :start_date, :end_date]
      end

      def all_or_uniquified_results(db)
        return stream.evaluate(db) unless options[:unique]
        stream.evaluate(db)
          .from_self
          .select_append { |o| o.row_number(:over, partition: uniquify_partition_columns, order: ordered_columns){}.as(:unique_rn) }
          .from_self
          .where(unique_rn: 1)
      end
    end
  end
end

