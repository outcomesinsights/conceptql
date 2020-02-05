require_relative "base"

module ConceptQL
  module Operators
    class OneInTwoOut < Base
      register __FILE__

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
      option :outpatient_minimum_gap, type: :string, default: '30d', instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years".'
      option :outpatient_maximum_gap, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years".'
      option :outpatient_event_to_return, type: :string, options: ['Initial Event', 'Confirming Event'], default: 'Initial Event', desc: 'Which event to pass downstream'

      validate_option DateAdjuster::VALID_INPUT, :outpatient_minimum_gap, :outpatient_maximum_gap

      default_query_columns

      include ConceptQL::Provenanceable
      output_column :admission_date
      output_column :discharge_date

      attr_reader :db

      def query(db)
        @db = db
        first_valid_event
      end

      def required_columns
        super | %i[criterion_domain start_date end_date]
      end

      private

      def condition_events
        upstream_query(db)
          .where(criterion_domain: 'condition_occurrence')
          .from_self
      end

      def all_inpatient_events
        limit_to_provenance(condition_events, %w(inpatient))
          .from_self
      end

      def valid_inpatient_events
        q = all_inpatient_events
          .from_self(alias: :og)
          .left_join(
            :admission_details_cql_view_v1,
            {
              Sequel[:ajv][:criterion_id] => Sequel[:og][:criterion_id],
              Sequel[:ajv][:criterion_table] => Sequel[:og][:criterion_table]
            },
            table_alias: :ajv
          )
          .auto_columns(
            admission_date: Sequel[:ajv][:admission_date],
            discharge_date: Sequel[:ajv][:discharge_date]
          )
          .require_columns(required_columns)
          .require_columns(:admission_date, :discharge_date)
          .auto_select
        unless options[:inpatient_length_of_stay].nil? || options[:inpatient_length_of_stay].to_i.zero?
          q = q.where{ |o| rdbms.days_between(o.admission_date, o.discharge_date) > options[:inpatient_length_of_stay].to_i }
        end

        date_to_report = if options[:inpatient_return_date] == 'Admit Date'
                           Sequel[:admission_date]
                         else
                           Sequel[:discharge_date]
                         end

        q.require_columns(required_columns)
          .auto_columns(start_date: date_to_report, end_date: date_to_report)
          .auto_select(alias: :valid_inpatient_events)
      end

      def outpatient_events
        limit_to_provenance(condition_events, %w(carrier_claim outpatient))
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
                        .where(matching_columns.map { |c| [initial[c], confirm[c]] })
                        .exclude({ initial[:criterion_id] => confirm[:criterion_id] })

        # In order to avoid many more comparisons of initial to confirm events, we now
        # filter the join by having only confirm events that come on or after initial events
        #
        # This ensures that initial events represent initial events and confirm events
        # represent confirming events
        sub_select = sub_select.exclude(confirm[:start_date] < initial[:start_date])


        if min_gap.present?
          sub_select = sub_select.where(Sequel.expr(confirm[:start_date]) >= DateAdjuster.new(self, min_gap).adjust(initial[:start_date]))
        end

        if max_gap.present?
          sub_select = sub_select.where(Sequel.expr(confirm[:start_date]) <= DateAdjuster.new(self, max_gap).adjust(initial[:start_date]))
        end

        q = outpatient_events.from_self(alias: outer_table)
              .where(sub_select.exists)

        q.require_columns(required_columns)
          .auto_columns(
            admission_date: :start_date,
            discharge_date: :end_date
          )
          .auto_select(alias: :valid_outpatient_events)
      end

      def all_valid_events
        valid_inpatient_events.union(valid_outpatient_events, all: true)
      end

      def first_valid_event
        all_valid_events
          .select_append { |o| o.row_number.function.over(partition: matching_columns , order: [:start_date, :criterion_id]).as(:rn) }
          .from_self
          .where(rn: 1)
      end
    end
  end
end

