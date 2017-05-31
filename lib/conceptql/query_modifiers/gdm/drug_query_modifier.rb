require_relative '../query_modifier'
require 'facets/kernel/try'

module ConceptQL
  module QueryModifiers
    module Gdm
      class DrugQueryModifier < QueryModifier

        def self.provided_columns
          [
            :drug_name,
            :drug_amount,
            :drug_amount_units,
            :drug_quantity,
            :drug_days_supply
          ]
        end

        def self.has_required_columns?(cols)
          needed = [:drug_exposure_detail_id].sort
          found = needed & cols
          p needed, found
          needed == found
        end

        def modified_query
          return query unless dm.table_cols(source_table).tap { |o| p o }.include?(:drug_exposure_detail_id)
          #TODO: Determine what actual columns to include for drug exposures under
          query.from_self(alias: :cc)
            .left_join(:drug_exposure_details___de, cc__drug_exposure_detail_id: :de__id)
            .left_join(:concepts___dose_con, de__dose_unit_concept_id: :dose_con__id)
            .left_join(:concepts___ing_con, cc__clinical_code_concept_id: :ing_con__id)
            .select_all(:cc)
            .select_append(:de__dose_value___drug_amount)
            .select_append(:dose_con__concept_text___drug_amount_units)
            .select_append(:ing_con__concept_text___drug_name)
            .select_append(:de__days_supply___drug_days_supply)
            .select_append(:de__refills___drug_quantity)
            .from_self
        end

        private

        def domain
          op.try(:domain) rescue nil
        end
      end
    end
  end
end
