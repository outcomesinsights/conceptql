# frozen_string_literal: true

require_relative "../query_modifier"

module ConceptQL
  module QueryModifiers
    module Gdm
      class ProviderQueryModifier < QueryModifier
        def self.provided_columns
          %i[provider_id context_specialty_concept_id practitioner_specialty_concept_id role_type_concept_id]
        end

        def self.has_required_columns?(cols)
          needed = %i[practitioner_id context_id].sort
          found = needed | cols
          !found.empty?
        end

        def modified_query
          if dm.table_cols(source_table).include?(:context_id)
            query.from_self(alias: :c)
                 .left_join(Sequel[:contexts_practitioners].as(:cp), Sequel[:c][:context_id] => Sequel[:cp][:context_id])
                 .left_join(Sequel[:practitioners].as(:p), Sequel[:p][:id] => Sequel[:cp][:practitioner_id])
                 .select_all(:c)
                 .select_append(
                   Sequel[:cp][:practitioner_id].as(:provider_id),
                   Sequel[:cp][:role_type_concept_id].as(:role_type_concept_id),
                   Sequel[:cp][:specialty_type_concept_id].as(:context_specialty_concept_id),
                   Sequel[:p][:specialty_concept_id].as(:practitioner_specialty_concept_id)
                 )
          else
            # The data model names the columns of the source table. ds.columns
            # asked the database for them while the SQL was built (bead
            # conceptql-6k8).
            cols = dm.table_cols(source_table)
            ds = query.select_all
            ds = if cols.include?(:provider_id)
                   ds
            elsif cols.include?(:practitioner_id)
                   ds.select_append(Sequel[:practitioner_id].as(:provider_id))
            else
                   ds.select_append(Sequel.cast(nil, :Bigint).as(:provider_id))
            end
            %i[role_type_concept_id context_specialty_concept_id practitioner_specialty_concept_id].each do |col|
              ds = ds.select_append(Sequel.cast(nil, :Bigint).as(col)) unless cols.include?(col)
            end
            ds
          end.from_self
        end
      end
    end
  end
end
