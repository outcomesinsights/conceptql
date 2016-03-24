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

      option :inpatient_length_of_stay, type: :integer
      option :inpatient_return_date, type: :string, options: ['Admit Date', 'Discharge Date'], default: 'Discharge Date'
      option :outpatient_minimum_gap, type: :string
      option :outpatient_maximum_gap, type: :string
      option :outpatient_event_to_return, type: :string, options: ['Initial Event', 'Confirming Event'], default: 'Initial Event'

      validate_required_options :outpatient_minimum_gap
      validate_option DateAdjuster::VALID_INPUT, :outpatient_minimum_gap, :outpatient_maximum_gap

      def query(db)
        ds = visit_query(db).clone(:force_columns=>table_columns(:visit_occurrence))
        inpatient = select_it(ds.where(place_of_service_concept_id: 8717), :visit_occurrence).from_self
        outpatient = select_it(ds.exclude(place_of_service_concept_id: 8717), :visit_occurrence).from_self

        date_diff = if db.database_type == :impala
          Sequel.function(:datediff, Sequel.function(:max, :start_date), Sequel.function(:min, :end_date))
        else
          Sequel.function(:max, :start_date) - Sequel.function(:min, :end_date)
        end

        gap = options[:gap] || 30
        valid_outpatient_people = outpatient
          .select_group(:person_id)
          .select_append(date_diff.as(:date_diff))
          .from_self
            .where{ date_diff() >= gap}

        relevant_outpatient = outpatient.where(person_id: valid_outpatient_people.select(:person_id))
        earliest(db, inpatient.union(relevant_outpatient))
      end

      def query_cols
        SELECTED_COLUMNS + [:rn]
      end

      private
      def visit_query(db)
        VisitOccurrence.new(nodifier, FakeOperator.new(nodifier, stream.evaluate(db).from_self, stream.domains)).query(db)
      end

      def earliest(db, query)
        cte_name = scope.add_extra_cte(:earliest,
            query.select_append { |o| o.row_number(:over, partition: :person_id, order: [Sequel.asc(:start_date), :criterion_domain, :criterion_id]){}.as(:rn) })
        db[cte_name]
          .from_self
          .where(rn: 1)
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

