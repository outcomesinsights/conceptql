require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module Gdm
      class LabQueryModifier < QueryModifier

        def self.provided_columns
          [
            :value_as_number,
            :value_as_string,
            :value_as_concept_id,
            :value_as_concept,
            :unit_concept_id,
            :unit_concept,
            :range_low,
            :range_high
          ]
        end

        def self.has_required_columns?(cols)
          needed = [:measurement_detail_id].sort
          found = needed & cols
          needed == found
        end

        def modified_query
          return query unless dm.table_cols(source_table).include?(:measurement_detail_id)

          query.from_self(alias: :cc)
            .left_join(Sequel[:measurement_details].as(:md), Sequel[:cc][:measurement_detail_id] => Sequel[:md][:id])
            .left_join(dm.concepts_table(query.db).as(:unit_con), Sequel[:md][:unit_concept_id] => Sequel[:unit_con][:id])
            .left_join(dm.concepts_table(query.db).as(:concept_con), Sequel[:md][:result_as_concept_id] => Sequel[:concept_con][:id])
            .select_all(:cc)
            .select_append(Sequel[:md][:result_as_number].as(:value_as_number))
            .select_append(Sequel[:md][:result_as_string].as(:value_as_string))
            .select_append(Sequel[:md][:result_as_concept_id].as(:value_as_concept_id))
            .select_append(Sequel[:concept_con][:concept_code].as(:value_as_concept))
            .select_append(Sequel[:md][:unit_concept_id].as(:unit_concept_id))
            .select_append(Sequel[:unit_con][:concept_code].as(:unit_concept))
            .select_append(Sequel[:md][:normal_range_low].as(:range_low))
            .select_append(Sequel[:md][:normal_range_high].as(:range_high))
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
