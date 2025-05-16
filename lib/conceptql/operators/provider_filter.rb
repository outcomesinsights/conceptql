# frozen_string_literal: true

require_relative 'operator'

module ConceptQL
  module Operators
    # Filters incoming records to only those that have been associated with
    # providers matching the given criteria.
    class ProviderFilter < Operator
      register __FILE__

      desc "Passes along records where the provider's specialty matches a given set of specialty_concept_ids."
      option :specialties, type: :string
      option :roles, type: :string
      category 'Filter Single Stream'
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      validate_required_options :specialties, :roles
      require_column :context_specialty_concept_id
      require_column :practitioner_specialty_concept_id
      require_column :role_type_concept_id
      default_query_columns

      def query(db)
        ds = stream.evaluate(db).from_self(alias: :upstream)

        specialty_concept_ids = options[:specialties].split(/\s*,\s*/)
        role_type_concept_ids = options[:roles].split(/\s*,\s*/)

        unless specialty_concept_ids.include?('*')
          spec_con_ids = specialty_concept_ids.map(&:to_i)
          ds = ds.where(
            Sequel.or(
              [
                [:context_specialty_concept_id, spec_con_ids],
                [:practitioner_specialty_concept_id, spec_con_ids]
              ]
            )
          )
        end

        unless role_type_concept_ids.include?('*')
          role_con_ids = role_type_concept_ids.map(&:to_i)
          ds = ds.where(role_type_concept_id: role_con_ids)
        end

        ds
      end

      def query_columns
        default_columns + [:specialty_concept_id]
      end
    end
  end
end
