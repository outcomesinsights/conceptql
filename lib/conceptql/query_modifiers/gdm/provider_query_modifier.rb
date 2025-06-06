# frozen_string_literal: true

require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module Gdm
      class ProviderQueryModifier < QueryModifier
        def self.provided_columns
          %i[provider_id specialty_concept_id]
        end

        def self.has_required_columns?(cols)
          needed = %i[practitioner_id context_id].sort
          found = needed & cols
          !found.empty?
        end

        def modified_query
          if dm.table_cols(source_table).include?(:context_id)
            query.from_self(alias: :c)
                 .join(Sequel[:contexts_practitioners].as(:cp), context_id: :context_id)
                 .select_all(:c)
                 .select_append(Sequel[:cp][:practitioner_id].as(:provider_id))
                 .select_append(Sequel[:cp][:specialty_type_concept_id].as(:specialty_concept_id))
          else
            query
              .select_all
              .select_append(Sequel[:practitioner_id].as(:provider_id))
              .select_append(Sequel.cast(nil, :Bigint).as(:specialty_concept_id))
          end.from_self
        end
      end
    end
  end
end
