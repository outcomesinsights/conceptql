# frozen_string_literal: true

require_relative 'gdm'

module ConceptQL
  module DataModel
    class GdmWide < Gdm
      def query_modifier_for(column)
        {
          visit_source_concept_id: ConceptQL::QueryModifiers::GdmWide::PoSQueryModifier,
          provider_id: ConceptQL::QueryModifiers::Gdm::ProviderQueryModifier,
          specialty_concept_id: ConceptQL::QueryModifiers::Gdm::ProviderQueryModifier,
          drug_name: ConceptQL::QueryModifiers::GdmWide::DrugQueryModifier,
          admission_date: ConceptQL::QueryModifiers::GdmWide::AdmissionDateQueryModifier,
          provenance_type: ConceptQL::QueryModifiers::GdmWide::ProvenanceQueryModifier,
          value_as_number: ConceptQL::QueryModifiers::GdmWide::LabQueryModifier
        }[column]
      end

      def table_by_domain(table)
        tab = super(table)
        tab = :observations if %i[clinical_codes collections].include?(tab)
        tab
      end

      def data_model
        :gdm_wide
      end
    end
  end
end
