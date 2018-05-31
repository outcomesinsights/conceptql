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
        if gdm?
          gdm(db)
        else
          events_with_common_visits(db).inject { |q, query| q.union(query, all: true) }
        end
      end

      def gdm(db)

        contexteds = upstreams.map do |stream|
          contextify(db, stream)
        end

        # Get all context_id's that are in all streams and do not share the same critierion_id
        first, *rest = *contexteds
        shared_context_ids = rest.inject(first.from_self(alias: :first)) do |q, shared_event|
            q.join(shared_event.select(:context_id, :criterion_id), context_id: :context_id) do |a,b|
            ~(Sequel.qualify(a,:criterion_id) =~ Sequel.qualify(b,:criterion_id) )
          end.select(Sequel[:first][:context_id]).distinct
        end.from_self

        name = cte_name(:shared_context_ids)
        shared_events = contexteds.map do |contexted|
          contexted.where(context_id: db[name])
        end

        shared_events.inject do |q, shared_event|
          q.union(shared_event)
        end.with(name, shared_context_ids)
      end

      def contextify(db, stream)
        stream.evaluate(db).from_self(alias: :s)
          .join(Sequel[:clinical_codes].as(:c), id: :criterion_id)
          .select_all(:s)
          .select_append(Sequel[:c][:context_id].as(:context_id))
          .where(criterion_domain: "condition_occurrence")
          .from_self
      end

      private

      def visit_occurrence_ids_in_common(db)
        @visit_occurrence_ids_in_common ||= upstream_queries(db).map { |q| q.select(:visit_occurrence_id) }.inject do |q, query|
          q.from_self(alias: :tab1)
            .join(query.as(:tab2), visit_occurrence_id: :visit_occurrence_id)
            .select(Sequel[:tab1][:visit_occurrence_id].as(:visit_occurrence_id))
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

