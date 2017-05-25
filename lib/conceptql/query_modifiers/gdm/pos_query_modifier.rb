require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module Gdm
      class PoSQueryModifier < QueryModifier
        attr :join_id, :table, :source_column, :column

        def initialize(*args)
          super
          @column = :place_of_service_concept_id
          @join_id = :context_id
          @table = :contexts
          @source_column = :pos_concept_id
        end

        def modified_query
          return query unless op.query_cols.include?(join_id)
          left_alias = "tab1".to_sym
          right_alias = "tab2".to_sym

          extra_table = query.db.from(table).select(Sequel.as(source_column, column), :id)
          ds = query.from_self(alias: left_alias)
          ds.left_join(extra_table.as(right_alias),
                      Sequel.qualify(left_alias, join_id) => Sequel.qualify(right_alias, :id))
                    .select_all(left_alias)
                    .select_append(Sequel.qualify(right_alias, column).as(column))
                    .from_self
        end
      end
    end
  end
end
