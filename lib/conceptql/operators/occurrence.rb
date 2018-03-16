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
      register __FILE__

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

      def query_cols
        dynamic_columns + [:rn]
      end

      def query(db)
        name = cte_name(:occurrences)
        db[name]
          .with(name, occurrences(db))
          .where(rn: occurrence.abs)
      end

      def occurrence
        @occurrence ||= arguments.first
      end

      def occurrences(db)
        stream.evaluate(db)
          .from_self
          .select_append { |o| o.row_number.function.over(partition: :person_id, order: ordered_columns).as(:rn) }
      end

      private

      def validate(db, opts = {})
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
        ordered_columns = [Sequel.send(asc_or_desc, rdbms.partition_fix(:start_date))]
        ordered_columns += [:criterion_id]
      end
    end
  end
end

