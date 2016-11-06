require_relative 'pass_thru'

module ConceptQL
  module Operators
    class CoReported < PassThru
      register __FILE__

      desc 'Passes through all events that were co-reported in a database. For OMOP CDM, an event is considered to be "co-reported" if it shares the same visit_occurrence as another event.'
      allows_many_upstreams
      category "Combine Streams"
      default_query_columns
      validate_at_least_one_upstream
      validate_no_arguments
      require_column :visit_occurrence_id

      def query(db)
        events_with_common_visits(db).inject { |q, query| q.union(query, all: true) }
      end

      private

      def visit_occurrence_ids_in_common(db)
        @visit_occurrence_ids_in_common ||= upstream_queries(db).map { |q| q.select(:visit_occurrence_id) }.inject do |q, query|
          q.from_self(alias: :tab1)
            .join(query.as(:tab2), tab1__visit_occurrence_id: :tab2__visit_occurrence_id)
            .select(:tab1__visit_occurrence_id___visit_occurrence_id)
        end
      end

      def events_with_common_visits(db)
        upstream_queries(db).map { |q| q.where(visit_occurrence_id: visit_occurrence_ids_in_common(db)).from_self }
      end

      def upstream_queries(db)
        @upstream_queries ||= upstreams.map do |expression|
          expression.evaluate(db).from_self
        end
      end
    end
  end
end

