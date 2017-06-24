require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module Omopv4Plus
      class PoSQueryModifier < QueryModifier
        attr :join_id, :table, :source_column, :column

        def self.provided_columns
          [:place_of_service_concept_id]
        end

        def self.has_required_columns?(cols)
          needed = [:place_of_service_concept_id].sort
          found = needed & cols
          needed == found
        end

        def initialize(*args)
          super
          @column = :place_of_service_concept_id
          @join_id = :visit_occurrence_id
          @table = :visit_occurrence
          @source_column = op.omopv4? ? :place_of_service_concept_id : :visit_source_concept_id
        end

        def modified_query
          return query unless dm.table_cols(source_table).include?(join_id)
          left_alias = "tab1".to_sym
          right_alias = "tab2".to_sym

          extra_table = query.db.from(table).select(Sequel.as(source_column, column), join_id)
          ds = query.from_self(alias: left_alias)
          ds.left_join(extra_table.as(right_alias),
                      Sequel.qualify(left_alias, join_id) => Sequel.qualify(right_alias, join_id))
                    .select_all(left_alias)
                    .select_append(Sequel.qualify(right_alias, column).as(column))
                    .from_self
        end
      end
    end
  end
end
