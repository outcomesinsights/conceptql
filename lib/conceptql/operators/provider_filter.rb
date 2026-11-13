# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    # Filters incoming records to only those that have been associated with
    # providers matching the given criteria.
    class ProviderFilter < Operator
      register __FILE__
      effects :keep, :change

      desc "Passes along the results whose provider matches the given specialties and roles. " \
           "Each option is a comma-separated list of concept IDs, and * matches any value."

      returns "The upstream results that have a provider who matches both the specialties and the roles. " \
              "A result can have more than one provider, so a result comes out once for each provider who matches. " \
              "Each result gets the columns provider_id, context_specialty_concept_id, practitioner_specialty_concept_id " \
              "and role_type_concept_id."

      option :specialties, type: :string,
                           meaning: "A comma-separated list of specialty concept IDs, such as 38003868 (Endocrinology, Diabetes & Metabolism Physician), " \
                                    "or * for any specialty. A provider matches when the specialty recorded for the provider on the claim, " \
                                    "or the provider's own specialty, is in the list."
      option :roles, type: :string,
                     meaning: "A comma-separated list of role concept IDs of the GDM_ROLE vocabulary, " \
                              "such as 100000067 (Attending physician) or 100176860 (Billing provider), or * for any role."

      example "Diabetes diagnoses with an endocrinologist as the attending physician",
              [ "provider_filter", [ "icd9", "250.00" ], { "specialties" => "38003868", "roles" => "100000067" } ]

      category "Filter Single Stream"
      diagram_base :temporal
      validate_one_upstream
      validate_required_options :specialties, :roles
      require_column :provider_id
      require_column :context_specialty_concept_id
      require_column :practitioner_specialty_concept_id
      require_column :role_type_concept_id
      default_query_columns

      def query(db)
        ds = stream.evaluate(db).from_self(alias: :upstream)

        specialty_concept_ids = options[:specialties].split(/\s*,\s*/)
        role_type_concept_ids = options[:roles].split(/\s*,\s*/)

        unless specialty_concept_ids.include?("*")
          spec_con_ids = specialty_concept_ids.map(&:to_i)
          ds = ds.where(
            Sequel.or(
              [
                [ :context_specialty_concept_id, spec_con_ids ],
                [ :practitioner_specialty_concept_id, spec_con_ids ]
              ]
            )
          )
        end

        unless role_type_concept_ids.include?("*")
          role_con_ids = role_type_concept_ids.map(&:to_i)
          ds = ds.where(role_type_concept_id: role_con_ids)
        end

        ds
      end

      def query_columns
        default_columns + %i[
          context_specialty_concept_id
          practitioner_specialty_concept_id
          role_type_concept_id
          provider_id
        ]
      end
    end
  end
end
