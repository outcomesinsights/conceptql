require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module GdmWide
      class DrugQueryModifier < QueryModifier

        def self.provided_columns
          [
            :drug_name,
            :drug_amount,
            :drug_amount_units,
            :drug_quantity,
            :drug_strength_source_value,
            :drug_days_supply
          ]
        end

        def self.has_required_columns?(cols)
          needed = [:dose_unit_concept_id].sort
          found = needed & cols
          needed == found
        end

        def modified_query
          return query unless dm.table_cols(source_table).include?(:dose_unit_concept_id)

          query.from_self(alias: :cc)
            .left_join(dm.concepts_table(query.db).as(:dose_con), Sequel[:cc][:dose_unit_concept_id] => Sequel[:dose_con][:id])
            .left_join(dm.concepts_table(query.db).as(:ing_con), Sequel[:cc][:clinical_code_concept_id] => Sequel[:ing_con][:id])
            .select_all(:cc)
            .select_append(Sequel[:cc][:dose_value].as(:drug_amount))
            .select_append(Sequel[:dose_con][:concept_text].as(:drug_amount_units))
            .select_append(Sequel[:ing_con][:concept_text].as(:drug_name))
            .select_append(Sequel[:cc][:days_supply].as(:drug_days_supply))
            .select_append(Sequel[:cc][:strength_source_value].as(:drug_strength_source_value))
            .select_append(Sequel[:cc][:quantity].as(:drug_quantity))
            .from_self
        end

        private

        def domain
          op.domain rescue nil
        end
      end
    end
  end
end
