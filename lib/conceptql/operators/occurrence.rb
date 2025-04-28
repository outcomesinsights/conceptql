# frozen_string_literal: true

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

      desc "Groups all records by person, then orders by start_date and finds the nth occurrence. Can be positive or negative, e.g 2 means 'second' and -3 means 'third from last'."

      argument :occurrence, type: :integer
      category 'Filter Single Stream'
      basic_type :temporal
      allows_one_upstream
      validate_at_least_one_upstream

      option :at_least, type: :string,
                        instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
      option :within, type: :string,
                      instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
      option :group_by_date, type: :boolean,
                             instructions: 'Choose whether to group by date when determining the nth occurrence, treating occurrences on the same day as a single occurrence'

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
        ds = if at_least_option || within_option
               query_complex(db)
             else
               query_simple(db)
             end
             .where(rn: occurrence.abs)

        return ds unless options[:group_by_date]

        ds = ds.from_self
               .select_append(
                 Sequel[rank_function]
                 .function.over(partition: matching_columns,
                                order: ordered_columns(needs_criterion_id: false)).as(:tie_breaking_rn)
               ).from_self.where(tie_breaking_rn: 1)
      end

      # With at_least or within option, return all matching occurrences that meet the date criteria by doing a self join.
      # If within is specified, assume an at_least of everything after the current event to not pick
      # prior occurrences when doing the self join.
      def query_complex(db)
        unless ConceptQL.avoid_ctes?
          input_name = cte_name(:occurrence_input)
          joined_name = cte_name(:occurrence_joined)
        end

        # Give a global row number to all rows, so that the self joined dataset can partition based on
        # the global row number when ordering
        input_ds = stream.evaluate(db)
                         .select_append(Sequel[:ROW_NUMBER].function.over(partition: matching_columns,
                                                                          order: ordered_columns(global: true)).as(:global_rn))

        first = Sequel[:first]
        rest = Sequel[:rest]
        base_input_ds = input_name ? Sequel[input_name] : input_ds
        joined_ds = db[base_input_ds.as(:first)]
                    .join(base_input_ds.as(:rest), matching_columns.map { |c| [c, c] }) do
          cond = rest[:global_rn] > first[:global_rn]
          cond &= rest[:start_date] >= adjust_date(at_least_option, first[:end_date]) if at_least_option
          cond &= rest[:start_date] <= adjust_date(within_option, first[:end_date]) if within_option
          cond | { rest[:global_rn] => first[:global_rn] }
        end
          .select_all(:rest)
          .select_append(first[:global_rn].as(:initial_rn))
          .select_append(Sequel[rank_function].function.over(partition: matching_columns.map { |c|
                           first[c]
                         } + [first[:global_rn]], order: ordered_columns(qualify: :rest)).as(:rn))

        joined_ds = if joined_name
                      db[joined_name]
                        .with(input_name, input_ds)
                        .with(joined_name, joined_ds)
                    else
                      joined_ds.from_self
                    end

        joined_ds.order(:global_rn)
      end

      # Without at_least or within option, only return the first occurrence for each person, if any.
      def query_simple(db)
        stream.evaluate(db)
              .select_append(Sequel[rank_function].function.over(partition: matching_columns,
                                                                 order: ordered_columns).as(:rn))
              .from_self
      end

      private

      def within_option
        return unless (v = options[:within])
        return if v.strip.empty?

        v
      end

      def at_least_option
        return unless (v = options[:at_least])
        return if v.strip.empty?

        v
      end

      def adjust_date(adjustment, column, reverse = false)
        adjuster = DateAdjuster.new(self, adjustment)
        adjuster.adjust(column, reverse)
      end

      def additional_validation(_db, _opts = {})
        if instance_of?(Occurrence)
          validate_one_argument
        else
          validate_no_arguments
        end
      end

      def asc_or_desc
        occurrence.negative? ? :desc : :asc
      end

      def qualify_with(qualifier, col)
        if qualifier
          Sequel.qualify(qualifier, col)
        else
          col
        end
      end

      def ordered_columns(opts = {})
        opts = { needs_criterion_id: options[:group_by_date] }.merge(opts)
        qualifier = opts[:qualify]
        start_date = rdbms.partition_fix(qualify_with(qualifier, :start_date), qualifier)
        start_date = Sequel.send(asc_or_desc, start_date) unless opts[:global]

        order = [start_date]
        unless opts[:needs_criterion_id]
          criterion_id = qualify_with(qualifier, :criterion_id)
          criterion_id = Sequel.send(asc_or_desc, criterion_id) unless opts[:global]
          order << criterion_id
        end
        order
      end
    end
  end
end
