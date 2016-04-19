require_relative 'operator'
require_relative 'visit_occurrence'
require_relative '../date_adjuster'

module ConceptQL
  module Operators
    class OneInTwoOut < Operator
      register __FILE__, :omopv4

      desc <<-EOF
Represents a common pattern in research algorithms: searching for a condition
that appears either two times in an outpatient setting with a 30-day gap or once
in an inpatient setting
      EOF
      allows_one_upstream
      validate_one_upstream
      validate_no_arguments
      category "Filter Single Stream"
      basic_type :temporal

      option :inpatient_length_of_stay, type: :integer, min: 0, default: 0, desc: 'Minimum length of inpatient stay reqiured for inpatient event to be valid'
      option :inpatient_return_date, type: :string, options: ['Admit Date', 'Discharge Date'], default: 'Discharge Date', desc: 'Which date to pass downstream in both the start_date and end_date fields'
      option :outpatient_minimum_gap, type: :integer, min: 0, default: 30, desc: 'Minimum number of days between outpatient events for the event to be valid'
      option :outpatient_maximum_gap, type: :integer, min: 0, desc: 'Maximum number of days between outpatient events for the event to be valid'
      option :outpatient_event_to_return, type: :string, options: ['Initial Event', 'Confirming Event'], default: 'Initial Event', desc: 'Which event to pass downstream'

      validate_required_options :outpatient_minimum_gap
      validate_option DateAdjuster::VALID_INPUT, :outpatient_minimum_gap, :outpatient_maximum_gap

      default_query_columns

      def query(db)
        faked_out = FakeOperator.new(nodifier,
          inpatient_events(db).union(outpatient_events(db).from_self),
          stream.domains)
        First.new(nodifier, faked_out).query(db)
      end

      private

      def inpatient_events(db)
        q = db[marked_events(db)]
              .where(type_id: inpatient_type_ids(db))
              .or(type_id: 0)

        unless options[:inpatient_length_of_stay].nil? || options[:inpatient_length_of_stay].zero?
          q = q.where{ |o| Sequel.date_sub(o.end_date, o.start_date) > options[:inpatient_length_of_stay] }
        end

        if options[:inpatient_return_date] == 'Admit Date'
          q = q.select(*(query_cols - [:end_date])).select_append(:start_date___end_date)
        else
          q = q.select(*(query_cols - [:start_date])).select_append(:end_date___start_date)
        end

        q.select(*SELECTED_COLUMNS)
      end

      def inpatient_type_ids(db)
        db[:concept___c]
          .join(:vocabulary___v, c__vocabulary_id: :v__vocabulary_id)
          .grep(:v__vocabulary_name, '% type', case_insensitive: true)
          .grep(:c__concept_name, '%inpatient%', case_insensitive: true)
          .select(:c__concept_id)
      end

      def outpatient_events(db)
        @outpat ||= scope.add_extra_cte(
          :outpat_events,
          db[marked_events(db)]
            .exclude(type_id: inpatient_type_ids(db))
        )

        min_gap = options[:outpatient_minimum_gap] || 30
        max_gap = options[:outpatient_maximum_gap] || 0

        q = db[@outpat].from_self(alias: :o1)
              .join(db[@outpat].as(:o2), o1__person_id: :o2__person_id)
              .exclude(o1__criterion_id: :o2__criterion_id, o1__criterion_domain: :o2__criterion_domain)

        if min_gap > 0
          q = q.where { o2__start_date >= o1__start_date + min_gap }
        end

        if max_gap > 0
          q = q.where { o2__start_date <= o1__start_date + max_gap }
        end

        if options[:outpatient_event_to_return] != 'Initial Event'
          q = q.select_all(:o2)
        else
          q = q.select_all(:o1)
        end

        faked_out = FakeOperator.new(nodifier, q.from_self, stream.domains)
        First.new(nodifier, faked_out).query(db).select(*SELECTED_COLUMNS)
      end

      def marked_events(db)
        # Just a heads up that I'm doing something sneaky in this line: I'm
        # asking the join to only happen if the criterion_domain of the row is
        # condition_occurrence
        #
        # Under PostgreSQL, this seems to still return all rows on the left,
        # but seems to avoid joining against condtion_occurrence unless the
        # row itself is a condition_occurrence
        @marked_events ||= scope.add_extra_cte(:in_out_events,
            stream.evaluate(db)
              .from_self(alias: :l)
              .left_join(:condition_occurrence___c, { c__condition_occurrence_id: :l__criterion_id, l__criterion_domain: 'condition_occurrence' })
              .select_all(:l)
              .select_append(Sequel.function(:coalesce, :c__condition_type_concept_id, 0).as(:type_id))
          )
      end

      class FakeOperator < Operator
        default_query_columns

        attr :domains
        def initialize(nodifier, query, domains)
          @nodifier = nodifier
          @query = query
          @domains = domains
          @options = {}
        end

        def query(db)
          @query
        end
      end
    end
  end
end

