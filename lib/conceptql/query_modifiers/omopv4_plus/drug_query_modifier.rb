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
          db = query.db
          drug_concept_ids = query.select(:drug_concept_id).distinct
          query.from_self(alias: :de)
            .left_join(micro_table(drug_concept_ids).as(:mt), drug_concept_id: :drug_concept_id)
            .select_all(:de)
            .select_append(Sequel[:de][:quantity].as(:drug_quantity))
            .select_append(Sequel[:de][:days_supply].as(:drug_days_supply))
            .select_append(Sequel[:mt][:amount_value].as(:drug_amount))
            .select_append(Sequel[:mt][:amount_unit].as(:drug_amount_units))
            .select_append(Sequel[:mt][:drug_name].as(:drug_name))
            .from_self
        end

        private

        def micro_table(drug_concept_ids)
          # TODO: Does drug_strength only have RXNORM concept_ids?
          # TODO: What is vocabulary for units?  Can we shrink concept table to just that vocab before joining?
          collapsed_strengths = db[:drug_strength]
            .where(drug_concept_id: drug_concept_ids)
            .select_group(:drug_concept_id)
            .select_append(
              Sequel.function(:min, :amount_value).as(:amount_value),
              Sequel.function(:min, :amount_unit).as(:amount_unit),
              Sequel.function(:count, 1).as(:dcount)
            )

          value_case = Sequel.case({ 1 => :amount_value }, nil, :dcount).as(:amount_value)
          unit_case = Sequel.case({ 1 => :amount_unit }, nil, :dcount).as(:amount_unit)

          collapsed_strengths = collapsed_strengths.from_self.select(:drug_concept_id, value_case, unit_case)

          db.from(Sequel[:concept].as(:dc))
            .left_join(collapsed_strengths, { drug_concept_id: :concept_id }, { table_alias: :ds })
            .where(Sequel[:dc][:concept_id] => drug_concept_ids)
            .select(
              Sequel[:dc][:concept_id].as(:drug_concept_id),
              Sequel[:dc][:concept_name].as(:drug_name),
              Sequel[:ds][:amount_value].as(:amount_value),
              Sequel[:ds][:amount_unit].as(:amount_unit)
            )
        end
      end
    end
  end
end
