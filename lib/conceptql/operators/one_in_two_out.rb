require_relative 'operator'
require_relative 'visit_occurrence'

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
      category %w(Temporal Relative)

      def types
        [:visit_occurrence]
      end

      def query(db)
        inpatient = select_it(visit_query(db).where(place_of_service_concept_id: 8717), :visit_occurrence).from_self
        outpatient = select_it(visit_query(db).exclude(place_of_service_concept_id: 8717), :visit_occurrence).from_self

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

      private
      def visit_query(db)
        VisitOccurrence.new(FakeOperator.new(stream.evaluate(db).from_self, stream.types)).query(db)
      end

      def earliest(db, query)
        db[:earliest]
          .with(:earliest,
            query.select_append { |o| o.row_number(:over, partition: :person_id, order: [Sequel.asc(:start_date), :criterion_type, :criterion_id]){}.as(:rn) })
          .where(rn: 1)
          .from_self
      end

      class FakeOperator < Operator
        attr :types
        def initialize(query, types)
          @query = query
          @types = types
        end

        def query(db)
          @query
        end
      end
    end
  end
end

