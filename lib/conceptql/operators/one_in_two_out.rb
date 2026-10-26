# frozen_string_literal: true

require_relative "operator"
require_relative "../date_adjuster"
require_relative "../behaviors/provenanceable"
require_relative "../behaviors/single_event"

module ConceptQL
  module Operators
    class OneInTwoOut < Operator
      include ConceptQL::Behaviors::SingleEvent

      # GDM only: omopv4_plus has no provenance vocabularies (conceptql-myp).
      register __FILE__, :gdm, :gdm_wide

      desc "Identifies an event that appears either once in an inpatient setting or twice within a specified interval in an outpatient setting."

      allows_one_upstream
      validate_one_upstream
      validate_no_arguments
      category "Filter Single Stream"
      basic_type :temporal

      option :inpatient_length_of_stay, type: :integer, min: 0, default: 0,
                                        desc: "Minimum length of inpatient stay (in days) required for inpatient event to be valid", label: "Inpatient Length of Stay (Days)"
      option :outpatient_minimum_gap, type: :string, default: "30d",
                                      instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years".'
      option :outpatient_maximum_gap, type: :string, default: "365d",
                                      instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years".'
      option :outpatient_event_to_return, type: :string, options: [ "Initial Event", "Confirming Event" ],
                                          default: "Initial Event", desc: "Which event to pass downstream"

      validate_option DateAdjuster::VALID_INPUT, :outpatient_minimum_gap, :outpatient_maximum_gap

      default_query_columns

      include ConceptQL::Provenanceable

      require_column :admission_date
      require_column :discharge_date

      # Each event is copied once per tag, by a cross join with a constant
      # table, so the upstream is read only once. The copies sort by date
      # and, at equal dates, by tag: a lower gap bound, then an event, then
      # an upper gap bound. Running sums over that order then count, at each
      # bound, the events on or after the lower bound and on or before the
      # upper bound, which is the old self-join's condition.
      LOWER = 0
      EVENT = 1
      UPPER = 2
      INPATIENT = 3

      attr_reader :db

      def query(db)
        @db = db
        first_valid_event.from_self
      end

      private

      def initial_mode?
        options[:outpatient_event_to_return] == "Initial Event"
      end

      def min_gap
        (options[:outpatient_minimum_gap] || "30d").to_s
      end

      def max_gap
        options[:outpatient_maximum_gap].to_s
      end

      # In the old self-join, a bare START or END resolved to the subquery's
      # table. In Initial Event mode that is the confirming event, so the
      # "gap" compares the confirming event with itself. It filters which
      # events can confirm and bounds nothing.
      def keyword_gap?(gap)
        initial_mode? && %w[start end].include?(gap.downcase)
      end

      def adjusted(gap)
        DateAdjuster.new(self, gap).adjust(:start_date)
      end

      # The earliest date a partner event may have. NULL when the bound is
      # NULL, as the old comparison then failed.
      def lower_bound
        return Sequel[:start_date] if min_gap.empty? || keyword_gap?(min_gap)

        bound = adjusted(min_gap)
        Sequel.case([ [ Sequel.expr(bound) > :start_date, bound ], [ Sequel.expr(bound) <= :start_date, :start_date ] ], nil)
      end

      # The latest date a partner event may have, or nil for no limit.
      def upper_bound
        return if max_gap.empty? || keyword_gap?(max_gap)

        adjusted(max_gap)
      end

      def partner_filter
        conditions = []
        conditions << (Sequel.expr(:start_date) >= adjusted(min_gap)) if keyword_gap?(min_gap)
        conditions << (Sequel.expr(:start_date) <= adjusted(max_gap)) if keyword_gap?(max_gap)
        return true if conditions.empty?

        Sequel.&(*conditions)
      end

      def inpatient_condition
        condition = build_where_from_codes(db, [ "inpatient" ])
        return condition if options[:inpatient_length_of_stay].nil? || options[:inpatient_length_of_stay].to_i.zero?

        Sequel.&(condition, rdbms.days_between(:admission_date, :discharge_date) > options[:inpatient_length_of_stay].to_i)
      end

      # The old self-join compared these columns with = and <>, so a NULL in
      # any of them kept an event from pairing.
      def outpatient_condition
        not_null = (matching_columns + [ :criterion_id ]).map { |c| Sequel.~(c => nil) }
        Sequel.&(build_where_from_codes(db, %w[carrier_claim outpatient]), *not_null)
      end

      def flag(condition)
        Sequel.case([ [ condition, 1 ] ], 0)
      end

      def condition_events
        db[stream.evaluate(db)]
          .where(criterion_domain: "condition_occurrence")
          .where(Sequel.|(inpatient_condition, outpatient_condition))
          .select(*query_cols)
          .select_append(flag(inpatient_condition).as(:is_inpatient), flag(outpatient_condition).as(:is_outpatient))
          .select_append(lower_bound.as(:lower_bound))
          .select_append(flag(partner_filter).as(:can_partner))
          .then { |ds| initial_mode? ? ds.select_append(event_key) : ds }
          .from_self
          # The upper bound gets its own SELECT. DuckDB compares 1 month as
          # equal to 30 days, so its optimizer merges date + 30 days and
          # date + 1 month in one SELECT list into one expression (bead
          # conceptql-a4j, seed conceptql-3wy). sequel-duckdb is to emit month
          # intervals in a form that avoids this; the split stays as a second
          # guard.
          .select_append(Sequel.as(upper_bound || Sequel.cast(nil, Date), :upper_bound))
          .from_self
      end

      # Tells an event's copies apart from other events' copies. Only Initial
      # Event mode needs it, to bring its two bounds' counts together.
      def event_key
        Sequel.function(:row_number).over(partition: matching_columns, order: %i[start_date criterion_id]).as(:event_key)
      end

      def tags
        [ LOWER, EVENT, UPPER, INPATIENT ]
          .map { |tag| db.select(Sequel.as(tag, :tag)) }
          .inject { |all, one| all.union(one, all: true, from_self: false) }
      end

      def bounds_valid
        valid = Sequel.~(lower_bound: nil)
        return valid unless upper_bound

        Sequel.&(valid, Sequel.~(upper_bound: nil), Sequel.expr(:lower_bound) <= :upper_bound)
      end

      def copies
        bound_tags = upper_bound ? [ LOWER, UPPER ] : [ LOWER ]
        condition_events
          .cross_join(tags, table_alias: :tags)
          .where(Sequel.|(
                   Sequel.&({ tag: INPATIENT }, { is_inpatient: 1 }),
                   Sequel.&({ tag: EVENT }, { is_outpatient: 1 }, Sequel.~(start_date: nil)),
                   Sequel.&({ tag: bound_tags }, { is_outpatient: 1 }, bounds_valid)
                 ))
          .select_all(:t1)
          .select_append(:tag)
          .select_append(Sequel.case({ LOWER => :lower_bound, UPPER => :upper_bound }, :start_date, :tag).as(:sweep_date))
          .select_append(weight.as(:weight))
          .from_self
      end

      # Initial Event mode counts events at its bounds. Confirming Event mode
      # counts the bound intervals that are open at each event.
      def weight
        if initial_mode?
          Sequel.case([ [ Sequel.&({ tag: EVENT }, { can_partner: 1 }), 1 ] ], 0)
        else
          Sequel.case({ LOWER => 1, UPPER => -1 }, 0, :tag)
        end
      end

      def running_sum(partition)
        Sequel.function(:sum, :weight).over(partition: partition, order: %i[sweep_date tag])
      end

      def total_sum(partition)
        Sequel.function(:sum, :weight).over(partition: partition)
      end

      # Counts from events with a different criterion_id only: the old
      # self-join excluded pairs that shared one.
      def counted_copies
        same = matching_columns + [ :criterion_id ]
        ds = copies.select_append((running_sum(matching_columns) - running_sum(same)).as(:partners))
        if initial_mode? && !upper_bound
          ds = ds.select_append((total_sum(matching_columns) - total_sum(same)).as(:all_partners))
        end
        ds.from_self
      end

      def valid_condition
        return Sequel.&({ tag: EVENT }, Sequel.expr(:partners) >= 1) unless initial_mode?

        Sequel.&({ tag: EVENT }, Sequel.expr(:upper_partners) - :lower_partners >= 1)
      end

      def bound_partners(tag)
        Sequel.function(:max, Sequel.case([ [ { tag: tag }, :partners ] ], nil))
              .over(partition: matching_columns + [ :event_key ])
      end

      def judged_copies
        return counted_copies unless initial_mode?

        upper = upper_bound ? bound_partners(UPPER) : Sequel.function(:max, :all_partners).over(partition: matching_columns + [ :event_key ])
        counted_copies
          .select_append(bound_partners(LOWER).as(:lower_partners), upper.as(:upper_partners))
          .from_self
      end

      def output_column(column)
        case column
        when :start_date then Sequel.case([ [ { tag: INPATIENT }, :admission_date ] ], :start_date).as(:start_date)
        when :end_date then Sequel.case([ [ { tag: INPATIENT }, :discharge_date ] ], :end_date).as(:end_date)
        else column
        end
      end

      def all_valid_events
        judged_copies
          .where(Sequel.|({ tag: INPATIENT }, valid_condition))
          .select(*dynamic_columns.map { |column| output_column(column) })
          .from_self
      end

      def first_valid_event
        all_valid_events
          .select_append do |o|
          o.row_number.function.over(partition: matching_columns,
                                     order: [
                                       :start_date, :criterion_id
                                     ]).as(:rn)
        end
          .from_self
          .where(rn: 1)
      end
    end
  end
end
