require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module Omopv4Plus
      class ProviderQueryModifier < QueryModifier
        def self.provided_columns
          [:provider_id]
        end

        def self.has_required_columns?(cols)
          needed = [:practitioner_id, :context_id].sort
          found = needed & cols
          !found.empty?
        end

        def modified_query
          if dm.table_cols(source_table).include?(:context_id)
            query.from_self(alias: :c)
              .join(Sequel[:contexts_practitioners].as(:cp), context_id: :context_id)
              .select_all(:c)
              .select_append(Sequel[:cp][:practitioner_id].as(:provider_id))
              .from_self
          else
            query
              .select_all
              .select_append(Sequel[:practitioner_id].as(:provider_id))
          end
        end

      end
    end
  end
end

