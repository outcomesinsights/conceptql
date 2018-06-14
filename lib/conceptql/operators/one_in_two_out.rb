require_relative 'operator'
require_relative 'visit_occurrence'
require_relative '../date_adjuster'
require_relative '../behaviors/provenanceable'

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
      require_column :admission_date
      require_column :discharge_date

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
          q = q.where{ |o| Sequel.date_sub(o.discharge_date, o.admission_date) > options[:inpatient_length_of_stay].to_i }
        end

        q = q.select(*(query_cols - [:start_date, :end_date]))

        q = if options[:inpatient_return_date] == 'Admit Date'
              q.select_append(Sequel[:admission_date].as(:start_date), Sequel[:admission_date].as(:end_date))
            else
              q.select_append(Sequel[:discharge_date].as(:start_date), Sequel[:discharge_date].as(:end_date))
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

        return_confirm = options[:outpatient_event_to_return] != 'Initial Event'

        outer_table = return_confirm ? :confirm : :initial
        sub_table = return_confirm ? :initial : :confirm

        confirm = Sequel[:confirm]
        initial = Sequel[:initial]

        sub_select = outpatient_events
                        .from_self(alias: sub_table)
                        .where(initial[:person_id] => confirm[:person_id])
                        .exclude(initial[:criterion_id] => confirm[:criterion_id])

        # In order to avoid many more comparisons of initial to confirm events, we now
        # filter the join by having only confirm events that come on or after initial events
        #
        # This ensures that initial events represent initial events and confirm events
        # represent confirming events
        sub_select = sub_select.exclude(confirm[:start_date] < initial[:start_date])


        if ConceptQL::Utils.present?(min_gap)
          sub_select = sub_select.where(Sequel.expr(confirm[:start_date]) >= DateAdjuster.new(self, min_gap).adjust(initial[:start_date]))
        end

        if ConceptQL::Utils.present?(max_gap)
          sub_select = sub_select.where(Sequel.expr(confirm[:start_date]) <= DateAdjuster.new(self, max_gap).adjust(initial[:start_date]))
        end

        q = outpatient_events.from_self(alias: outer_table)
              .where(sub_select.exists)

        q.from_self.select(*dynamic_columns).from_self
      end

      def all_valid_events
        valid_inpatient_events.union(valid_outpatient_events, all: true)
      end

      def first_valid_event
        all_valid_events
          .select_append { |o| o.row_number.function.over(partition: :person_id, order: [ :start_date, :criterion_id ]).as(:rn) }
          .from_self
          .where(rn: 1)
      end
    end
  end
end

