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

      option :at_least, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
      option :within, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
      option :group_by_date, type: :boolean, instructions: 'Choose whether to group by date when determining the nth occurrence, treating occurrences on the same day as a single occurrence'

      def query_cols
        dynamic_columns + [:rn]
      end

      def occurrence
        @occurrence ||= arguments.first
      end

      def query(db)
        function = options[:group_by_date] ? :DENSE_RANK : :ROW_NUMBER
        at_least_option = options[:at_least]
        within_option = options[:within]
        name = cte_name(:occurrences)

        if at_least_option || within_option
          ordered_name = cte_name(:ordered_occurrences)
          ordered = stream.evaluate(db)
            .from_self
            .select_append(Sequel[function].function.over(partition: :person_id, order: ordered_columns).as(:rn))

          first_name = cte_name(:first_occurrences)
          first = db[ordered_name]
            .where(:rn=>1)
            .select(:person_id)

          joined_name = cte_name(:joined_occurrences)
          joined = db[ordered_name]
            .join(first_name, person_id: :person_id)
            .select_all(ordered_name)

          if at_least_option
            first = first.select_append(adjust_date(at_least_option, Sequel[:end_date]).as(:after))
            joined = joined.where(Sequel[ordered_name][:start_date] >= Sequel[first_name][:after])
          end
          if within_option
            first = first.select_append(adjust_date(within_option, Sequel[:end_date]).as(:before))
            joined = joined.where(Sequel[ordered_name][:start_date] <= Sequel[first_name][:before])
          end

          first = first
            .from_self
            .select_group(:person_id)

          if at_least_option
            first = first.select_append{min(:after).as(:after)}
          end
          if within_option
            first = first.select_append{max(:before).as(:before)}
          end

          adjustments_name = cte_name(:adjustment_occurrences)
          adjustments = db[joined_name]
            .exclude(:rn=>1)
            .select_group(:person_id)
            .select_append{min(:rn).as(:min_rn)}

          adjusted_name = cte_name(:adjusted_occurrences)
          adjusted = db[joined_name]
            .join(adjustments_name, person_id: :person_id)
            .select_all(joined_name)
            .where((Sequel[:rn] - :min_rn)=>occurrence-2)

          db[adjusted_name]
            .with(ordered_name, ordered)
            .with(first_name, first)
            .with(joined_name, joined)
            .with(adjustments_name, adjustments)
            .with(adjusted_name, adjusted)
        else
          ds = stream.evaluate(db)
            .select_append(Sequel[function].function.over(partition: :person_id, order: ordered_columns).as(:rn))
            .from_self
            .where(rn: occurrence.abs)
          db[name].with(name, ds)
        end
      end

      private

      def adjust_date(adjustment, column, reverse = false)
        adjuster = DateAdjuster.new(self, adjustment)
        adjuster.adjust(column, reverse)
      end

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
        order = [Sequel.send(asc_or_desc, rdbms.partition_fix(:start_date))]
        order << :criterion_id unless options[:group_by_date]
        order
      end
    end
  end
end

