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

      #option :at_least, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
      #option :within, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
      option :group_by_date, type: :boolean, instructions: 'Choose whether to group by date when determining the nth occurrence, treating occurrences on the same day as a single occurrence'

      def query_cols
        dynamic_columns + [:rn]
      end

      def occurrence
        @occurrence ||= arguments.first
      end

      def query(db)
        function = options[:group_by_date] ? :DENSE_RANK : :ROW_NUMBER
        #at_least_option = options[:at_least]
        #within_option = options[:within]
        name = cte_name(:occurrences)
        main_ds = db[name]
=begin
        if at_least_option || within_option
          unique_ds = stream.evaluate(db)
            .from_self
            .select_append(Sequel[:ROW_NUMBER].function.over.as(:global_rn))

          uname = cte_name(:unique_occurrences)

          subquery = db[Sequel.as(uname, :b)]
            .where{{:person_id=>a[:person_id]}}
            .select(:global_rn)
            .select_append((Sequel[function].function.over(partition: :person_id, order: ordered_columns) + 1).as(:rn))

          if at_least_option
            subquery = subquery.where(Sequel[:b][:start_date] >= adjust_date(at_least_option, Sequel[:a][:end_date]))
          end
          if within_option
            subquery = subquery.where(Sequel[:b][:start_date] <= adjust_date(within_option, Sequel[:a][:end_date]))
          end

          subquery = subquery
            .from_self
            .where(rn: occurrence.abs)
            .select(:global_rn)

          ds = db[Sequel.as(uname, :a)]
            .where(:global_rn=>subquery)
            .from_self

          main_ds.with(uname, unique_ds).with(name,ds)
=end
    #    else
          ds = stream.evaluate(db)
            .select_append(Sequel[function].function.over(partition: :person_id, order: ordered_columns).as(:rn))
            .from_self
            .where(rn: occurrence.abs)
          main_ds.with(name, ds)
    #    end
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

