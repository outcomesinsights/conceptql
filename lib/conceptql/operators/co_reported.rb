# frozen_string_literal: true

require_relative "pass_thru"

module ConceptQL
  module Operators
    class CoReported < PassThru
      register __FILE__

      def events_per_patient
        upstreams.all? { |u| u.events_per_patient == :single } ? :single : :multiple
      end

      def multiple_vocabularies
        return true if upstreams.any?(&:multiple_vocabularies)

        vocabularies.length > 1
      end

      desc "Passes along the events of its upstream streams that were reported in the same source record " \
           "(the same context). A record is kept only if every upstream stream " \
           "has at least one event in it. If any one upstream has no event in a record, the events of all " \
           "streams in that record are dropped, without a warning."

      allows_many_upstreams
      category "Combine Streams"
      default_query_columns
      validate_at_least_one_upstream
      validate_no_arguments
      require_column :context_id

      def query(db)
        contexteds = upstreams.map do |stream|
          [ stream.cte_name(:contextified), contextify(db, stream) ]
        end.to_h

        # Get all context_id's that are in all streams and do not share the same critierion_id
        first, *rest = *contexteds.keys
        shared_context_ids = rest.inject(db[first].select(:context_id)) do |q, next_cte|
          q.intersect(db[next_cte].select(:context_id))
        end
        # shared_context_ids = rest.inject(first.from_self(alias: :first)) do |q, shared_event|
        #    q.join(shared_event.select(:context_id, :criterion_id), context_id: :context_id) do |a,b|
        #    ~(Sequel.qualify(a,:criterion_id) =~ Sequel.qualify(b,:criterion_id) )
        #  end.select(Sequel[:first][:context_id]).distinct
        # end.from_self

        if ConceptQL.avoid_ctes?
          context_id_ds = shared_context_ids
        else
          name = cte_name(:shared_context_ids)
          context_id_ds = db[name]
        end

        shared_events = contexteds.keys.map do |contexted|
          db[contexted].where(context_id: context_id_ds).select(*query_cols)
        end

        ds = shared_events.inject do |q, shared_event|
          q.union(shared_event)
        end

        contexteds.each do |name, query|
          ds = ds.with(name, query)
        end
        if name
          opts = {}
          opts[:materialized] = true if rdbms.supports_materialized?
          ds = ds.with(name, shared_context_ids, opts)
        end

        ds
      end

      def contextify(db, stream)
        stream.evaluate(db).from_self(alias: :s)
        # .join(Sequel[:clinical_codes].as(:c), id: :criterion_id)
        # .select_all(:s)
        # .select_append(Sequel[:c][:context_id].as(:context_id))
        # .from_self
      end
    end
  end
end
