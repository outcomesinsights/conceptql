require_relative 'pass_thru'

module ConceptQL
  module Operators
    class CoReported < PassThru
      register __FILE__

      desc 'For each upstream set of results, only those results sharing a common context or visit_occurrence accross all streams are passed through'
      allows_many_upstreams
      category "Combine Streams"
      default_query_columns
      validate_at_least_one_upstream
      validate_no_arguments

      def query(db)
        contexteds = upstreams.map do |stream|
          contextify(db, stream)
        end

        context_ids_only = contexteds.map do |contexted|
          contexted.select(:context_id)
        end

        shared_context_ids = context_ids_only.inject do |q, tab|
          q.intersect(tab)
        end

        shared_events = contexteds.map do |contexted|
          contexted.where(context_id: db[:shared_context_ids])
        end

        shared_events.inject do |q, shared_event|
          q.union(shared_event)
        end.with(:shared_context_ids, shared_context_ids)
      end

      def contextify(db, stream)
        stream.evaluate(db).from_self(alias: :s)
          .join(:clinical_codes___c, c__id: :s__criterion_id)
          .select_all(:s)
          .select_append(:c__context_id___context_id)
          .from_self
      end
    end
  end
end
