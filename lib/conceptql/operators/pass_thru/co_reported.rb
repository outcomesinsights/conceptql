require_relative "base"

module ConceptQL
  module Operators
    module PassThru
      class CoReported < Base
        register __FILE__

        desc 'Passes through all events that were co-reported in a database. For OMOP CDM, an event is considered to be "co-reported" if it shares the same visit_occurrence as another event.'
        allows_many_upstreams
        category "Combine Streams"
        default_query_columns
        validate_at_least_one_upstream
        validate_no_arguments

        def query(db)
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

          if ConceptQL.avoid_ctes?
            context_id_ds = shared_context_ids
          else
            name = cte_name(:shared_context_ids)
            context_id_ds = db[name]
          end

          shared_events = contexteds.map do |contexted|
            contexted.where(context_id: context_id_ds)
          end

          ds = shared_events.inject do |q, shared_event|
            q.union(shared_event)
          end

          if name
            ds = ds.with(name, shared_context_ids)
          end

          ds
        end

        def contextify(db, stream)
          stream.evaluate(db).from_self(alias: :s)
            .join(Sequel[:clinical_codes].as(:c), id: :criterion_id)
            .select_all(:s)
            .select_append(Sequel[:c][:context_id].as(:context_id))
            .from_self
        end
      end
    end
  end
end
