require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module Gdm
      class ProviderQueryModifier < QueryModifier
        def self.provided_columns
          [:provider_id]
        end

        def self.has_required_columns?(cols)
          puts "*"*80
          p cols
          puts "*"*80
          needed = [:practitioner_id, :context_id].sort
          found = needed & cols
          !found.empty?
        end

        def modified_query
          p source_table
          if dm.table_cols(source_table).include?(:context_id)
            query.from_self(alias: "c")
              .join(:contexts_practitioners___cp, cp__context_id: :c__context_id)
              .select_all(:c)
              .select_append(:cp__practitioner_id___provider_id)
          else
            query
              .select_all
              .select_append(:practitioner_id___provider_id)
          end.from_self
        end

      end
    end
  end
end

