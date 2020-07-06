require_relative 'operator'

module ConceptQL
  module Operators
    # Filters incoming events to only those that have been associated with
    # providers matching the given criteria.
    class ProviderFilter < Operator
      register __FILE__

      desc "Filters incoming events to only those that match the associated providers based on provider specialty concept_ids."
      option :specialties, type: :string
      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      validate_required_options :specialties
      require_column :provider_id
      default_query_columns

      # TODO: Use specialty field in contexts_practitioners
      def query(db)
        db.from(stream.evaluate(db))
          .where(provider_id: matching_provider_ids(db))
      end

    private
      def matching_provider_ids(db)
        specialty_concept_ids = options[:specialties].split(/\s*,\s*/).map(&:to_i)
        q_practitioners = db.from(dm.table_by_domain(:provider))
          .where(specialty_concept_id: specialty_concept_ids)
          .select(dm.pk_by_domain(:provider))
        q_contexts = db.from(:contexts_practitioners)
                        .where(specialty_type_concept_id: specialty_concept_ids)
                        .select(:practitioner_id)

        q_practitioners.union(q_contexts, all: true)
      end
    end
  end
end


