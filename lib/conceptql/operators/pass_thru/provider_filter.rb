require_relative "base"

module ConceptQL
  module Operators
    # Filters incoming events to only those that have been associated with
    # providers matching the given criteria.
    class ProviderFilter < Base
      register __FILE__

      desc "Filters incoming events to only those that match the associated providers based on provider specialty concept_ids."
      option :specialties, type: :string
      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      validate_required_options :specialties

      # TODO: Use specialty field in contexts_practitioners
      def query(db)
        upstream_query(db)
          .from_self(alias: :og)
          .semi_join(
            :providers_join_view_v1,
            {
              Sequel[:pjv][:specialty_concept_id] => specialty_concept_ids,
              Sequel[:pjv][:criterion_id] => Sequel[:og][:criterion_id],
              Sequel[:pjv][:criterion_table] => Sequel[:og][:criterion_table]
            },
            table_alias: :pjv
        )
      end

    private
      def specialty_concept_ids
        options[:specialties].split(/\s*,\s*/).map(&:to_i)
      end
    end
  end
end


