require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module GdmWide
      class ProvenanceQueryModifier < QueryModifier
        RELATED_COLUMNS = %w(
          provenance_concept_id
          source_type_concept_id
        ).sort.map(&:to_sym)

        attr :db

        def self.provided_columns
          [
            :file_provenance_type,
            :code_provenance_type
          ]
        end

        def self.has_required_columns?(cols)
          !(RELATED_COLUMNS & cols).empty?
        end

        def modified_query
          return query unless self.class.has_required_columns?(dm.table_cols(source_table))
          query.from_self
            .select_append(Sequel[:source_type_concept_id].as(:file_provenance_type),
                           Sequel[:provenance_concept_id].as(:code_provenance_type))
            .from_self
        end
      end
    end
  end
end



