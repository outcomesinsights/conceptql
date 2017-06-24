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
            .left_join(micro_table.as(:mt), mt__drug_concept_id: :de__drug_concept_id)
            .select_all(:de)
            .select_append(:mt__amount_value___drug_amount)
            .select_append(:mt__amount_unit___drug_amount_units)
            .select_append(:mt__drug_name___drug_name)
            .from_self
        end

        private

        def micro_table
          # TODO: Does drug_strength only have RXNORM concept_ids?
          # TODO: What is vocabulary for units?  Can we shrink concept table to just that vocab before joining?
          db.from(:drug_strength___ds)
            .join(:concept___dc, ds__drug_concept_id: :dc__concept_id)
            .select(
              :ds__drug_concept_id___drug_concept_id,
              :ds__amount_value___amount_value,
              :ds__amount_unit___amount_unit,
              :dc__concept_name___drug_name,
            )
        end
      end
    end
  end
end
