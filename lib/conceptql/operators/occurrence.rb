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

      def rank_function
        options[:group_by_date] ? :DENSE_RANK : :ROW_NUMBER
      end

      def query(db)
        ds = if options[:at_least] || options[:within]
          query_complex(db)
        else
          query_simple(db)
        end
        
        ds.where(rn: occurrence.abs)
      end

      # With at_least or within option, return all matching occurrences that meet the date criteria by doing a self join.
      # If within is specified, assume an at_least of everything after the current event to not pick
      # prior occurrences when doing the self join.
      def query_complex(db)
        at_least_option = options[:at_least]
        within_option = options[:within]
        input_name = cte_name(:occurrence_input)

        # Give a global row number to all rows, so that the self joined dataset can partition based on
        # the global row number when ordering
        input_ds = stream.evaluate(db)
          .select_append(Sequel[:ROW_NUMBER].function.over(partition: :person_id, order: ordered_columns(:global=>true)).as(:global_rn))

        first = Sequel[:first]
        rest = Sequel[:rest]
        joined_name = cte_name(:occurrence_joined)
        joined_ds = db[Sequel[input_name].as(:first)]
          .join(Sequel[input_name].as(:rest), :person_id=>:person_id) do
            cond = rest[:global_rn] > first[:global_rn]
            if at_least_option
              cond &= rest[:start_date] >= adjust_date(at_least_option, first[:end_date])
            end
            if within_option
              cond &= rest[:start_date] <= adjust_date(within_option, first[:end_date])
            end
            cond | {rest[:global_rn] => first[:global_rn]}
          end
          .select_all(:rest)
          .select_append(first[:global_rn].as(:initial_rn))
          .select_append(Sequel[rank_function].function.over(partition: [first[:person_id], first[:global_rn]], order: ordered_columns(:qualify=>:rest)).as(:rn))

        db[joined_name]
          .with(input_name, input_ds)
          .with(joined_name, joined_ds)
          .order(:global_rn)
      end

      # Without at_least or within option, only return the first occurrence for each person, if any.
      def query_simple(db)
        stream.evaluate(db)
          .select_append(Sequel[rank_function].function.over(partition: :person_id, order: ordered_columns).as(:rn))
          .from_self
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

      def qualify_with(qualifier, col)
        if qualifier
          Sequel.qualify(qualifier, col)
        else
          col
        end
      end

      def ordered_columns(opts={})
        qualifier = opts[:qualify]
        start_date = rdbms.partition_fix(qualify_with(qualifier, :start_date), qualifier)
        unless opts[:global]
          start_date = Sequel.send(asc_or_desc, start_date)
        end

        order = [start_date]
        unless options[:group_by_date]
          criterion_id = qualify_with(qualifier, :criterion_id)
          unless opts[:global]
            criterion_id = Sequel.send(asc_or_desc, criterion_id)
          end
          order << criterion_id
        end
        order
      end
    end
  end
end

