module ConceptQL
  module Behaviors
    module Drugish
      def self.included(base)
        base.output_column(:drug_name)
        base.output_column(:drug_amount)
        base.output_column(:drug_amount_units)
        base.output_column(:drug_quantity)
        base.output_column(:drug_days_supply)
      end

      def available_join_tables
        super + [
          drug_exposure_details_info,
          dose_concept_info,
          ingredient_concept_info
        ]
      end

      def drug_exposure_details_info
        JoinTableInfo.new(
          type: :left,
          table: :drug_exposure_details,
          alias: :de,
          join_criteria: { Sequel[:tab][:drug_exposure_detail_id] => Sequel[:de][:id] },
          for_columns: [ :drug_amount, :drug_days_supply ]
        )
      end

      def dose_concept_info
        JoinTableInfo.new(
          type: :left,
          table: :concepts,
          alias: :dose_con,
          join_criteria: { Sequel[:de][:dose_unit_concept_id] => Sequel[:dose_con][:id] },
          for_columns: [ :drug_amount_units ]
        )
      end

      def ingredient_concept_info
        JoinTableInfo.new(
          type: :left,
          table: :concepts,
          alias: :ing_con,
          join_criteria: { Sequel[:tab][:clinical_code_concept_id] => Sequel[:ing_con][:id] },
          for_columns: [ :drug_name ]
        )
      end

      def available_columns
        super.merge({
          drug_name: Sequel[:ing_con][:concept_text],
          drug_amount: Sequel[:de][:dose_value],
          drug_amount_units: Sequel[:dose_con][:concept_text],
          drug_quantity: Sequel[:tab][:quantity],
          drug_days_supply: Sequel[:de][:days_supply]
        })
      end
    end
  end
end
