require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module Omopv4Plus
      class ProviderQueryModifier < QueryModifier
        def self.provided_columns
          [:provider_id]
        end

        def self.has_required_columns?(cols)
          cols.find { |col| col.to_s =~ /provider_id/ }
        end

        def modified_query
          col = self.class.has_required_columns?(dm.table_cols(source_table))
          return query if col.nil? || col.to_sym == :provider_id
          query.select_append(Sequel[col].as(:provider_id)).from_self
        end
      end
    end
  end
end

