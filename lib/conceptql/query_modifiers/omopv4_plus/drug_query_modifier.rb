require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module Omopv4Plus
      class DrugQueryModifier < QueryModifier
        attr :db

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
          needed = [:drug_concept_id].sort
          found = needed & cols
          needed == found
        end

        def initialize(*args)
          super
          @db = query.db
        end

        def modified_query
          return query unless dm.table_cols(source_table).include?(:drug_concept_id)
          query.from_self(alias: :de)
            .left_join(micro_table.as(:mt), drug_concept_id: :drug_concept_id)
            .select_all(:de)
            .select_append(Sequel[:de][:quantity].as(:drug_quantity))
            .select_append(Sequel[:de][:days_supply].as(:drug_days_supply))
            .select_append(Sequel[:mt][:amount_value].as(:drug_amount))
            .select_append(Sequel[:mt][:amount_unit].as(:drug_amount_units))
            .select_append(Sequel[:mt][:drug_name].as(:drug_name))
            .from_self
        end

        private

        def micro_table
          # TODO: Does drug_strength only have RXNORM concept_ids?
          # TODO: What is vocabulary for units?  Can we shrink concept table to just that vocab before joining?
          db.from(Sequel[:concept].as(:dc))
            .left_join(Sequel[:drug_strength].as(:ds), drug_concept_id: :concept_id)
            .select(
              Sequel[:dc][:concept_id].as(:drug_concept_id),
              Sequel[:dc][:concept_name].as(:drug_name),
              Sequel[:ds][:amount_value].as(:amount_value),
              Sequel[:ds][:amount_unit].as(:amount_unit),
            )
        end
      end
    end
  end
end
