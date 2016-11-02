require_relative 'operator'
require_relative 'visit_occurrence'
require_relative '../date_adjuster'
require_relative '../behaviors/provenanceable'
require 'facets/kernel/blank'

module ConceptQL
  module Operators
    class OneInTwoOut < Operator
      register __FILE__

      include ConceptQL::Provenanceable

      desc <<-EOF
Represents a common pattern in research algorithms: searching for an event
that appears either once in an inpatient setting or
twice in an outpatient setting with a 30-day gap.
      EOF
      allows_one_upstream
      validate_one_upstream
      validate_no_arguments
      category "Filter Single Stream"
      basic_type :temporal

      option :inpatient_length_of_stay, type: :integer, min: 0, default: 0, desc: 'Minimum length of inpatient stay (in days) required for inpatient event to be valid', label: 'Inpatient Length of Stay (Days)'
      option :inpatient_return_date, type: :string, options: ['Admit Date', 'Discharge Date'], default: 'Discharge Date', desc: 'Which date to pass downstream in both the start_date and end_date fields'
      option :outpatient_minimum_gap, type: :string, default: '30d', desc: 'Minimum number of days between outpatient events for the event to be valid'
      option :outpatient_maximum_gap, type: :string, desc: 'Maximum number of days between outpatient events for the event to be valid'
      option :outpatient_event_to_return, type: :string, options: ['Initial Event', 'Confirming Event'], default: 'Initial Event', desc: 'Which event to pass downstream'

      validate_option DateAdjuster::VALID_INPUT, :outpatient_minimum_gap, :outpatient_maximum_gap

      default_query_columns

      require_column :provenance_type

      attr_reader :db

      def query(db)
        @db = db
        first_valid_event.from_self
      end

      private

      def condition_events
        db[stream.evaluate(db)]
          .where(criterion_domain: 'condition_occurrence')
          .exclude(provenance_type: nil)
          .from_self
      end

      def all_inpatient_events
        condition_events
          .where(provenance_type: to_concept_id(:inpatient))
          .from_self
      end

      def valid_inpatient_events
        q = all_inpatient_events
        unless options[:inpatient_length_of_stay].nil? || options[:inpatient_length_of_stay].to_i.zero?
          q = q.where{ |o| Sequel.date_sub(o.end_date, o.start_date) > options[:inpatient_length_of_stay].to_i }
        end

        if options[:inpatient_return_date] != 'Admit Date'
          q = q.select(*(query_cols - [:start_date])).select_append(:end_date___start_date)
        end

        q.from_self.select(*dynamic_columns).from_self
      end

      def outpatient_events
        condition_events
          .where(provenance_type: to_concept_id(:claim) + to_concept_id(:outpatient))
          .from_self
      end

      def valid_outpatient_events

        min_gap = options[:outpatient_minimum_gap] || "30d"

        max_gap = options[:outpatient_maximum_gap]

        q = outpatient_events.from_self(alias: :o1)
              .join(outpatient_events.as(:o2), o1__person_id: :o2__person_id)
              .exclude(o1__criterion_id: :o2__criterion_id)

        if min_gap.present?
          q = q.where { o2__start_date >= DateAdjuster.new(min_gap).adjust(:o1__start_date) }
        end

        if max_gap.present?
          q = q.where { o2__start_date <= DateAdjuster.new(max_gap).adjust(:o1__start_date) }
        end

        if options[:outpatient_event_to_return] != 'Initial Event'
          q = q.select_all(:o2)
        else
          q = q.select_all(:o1)
        end

        q.from_self
      end

      def all_valid_events
        valid_inpatient_events.union(valid_outpatient_events, all: true)
      end

      def first_valid_event
        all_valid_events
          .select_append { |o| o.row_number(:over, partition: :person_id, order: [ :start_date, :criterion_id ]){}.as(:rn) }
          .from_self
          .where(rn: 1)
      end
    end
  end
end

