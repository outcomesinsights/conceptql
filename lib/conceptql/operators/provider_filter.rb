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
      require_column :specialty_concept_id
      default_query_columns

      # TODO: Use specialty field in contexts_practitioners
      def query(db)
        specialty_concept_ids = options[:specialties].split(/\s*,\s*/).map(&:to_i)
        stream.evaluate(db).from_self(alias: :upstream)
          .where(specialty_concept_id: specialty_concept_ids)
#          .join(matching_provider_ids(db), [:provider_id], table_alias: :mp)
#          .select_all(:upstream)
#          .select_append(Sequel[:mp][:specialty_concept_id].as(:specialty_concept_id))
      end

      def query_columns
        default_columns + [:specialty_concept_id]
      end

    private
      def matching_provider_ids(db)
        specialty_concept_ids = options[:specialties].split(/\s*,\s*/).map(&:to_i)

        q_practitioners = db.from(dm.table_by_domain(:provider))
          .where(specialty_concept_id: specialty_concept_ids)
          .select(Sequel[dm.pk_by_domain(:provider)].as(:provider_id), :specialty_concept_id)
        q_contexts = db.from(:contexts_practitioners)
                        .where(specialty_type_concept_id: specialty_concept_ids)
          .select(Sequel[:practitioner_id].as(:provider_id), Sequel[:specialty_type_concept_id].as(:specialty_concept_id))

        q_practitioners.union(q_contexts, all: true)
      end
    end
  end
end


