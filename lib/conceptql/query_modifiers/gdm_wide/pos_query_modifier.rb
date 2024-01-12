require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module GdmWide
      class PoSQueryModifier < QueryModifier
        attr :source_column, :column

        def self.provided_columns
          [:visit_source_concept_id]
        end

        def self.has_required_columns?(cols)
          needed = [:context_id].sort
          found = needed & cols
          needed == found
        end

        def initialize(*args)
          super
          @column = :visit_source_concept_id
          @source_column = :pos_concept_id
        end

        def modified_query
          return query unless dm.table_cols(source_table).include?(:context_id)
          ds = query.from_self
            .select_append(Sequel[source_column].as(column))
            .from_self
        end
      end
    end
  end
end
