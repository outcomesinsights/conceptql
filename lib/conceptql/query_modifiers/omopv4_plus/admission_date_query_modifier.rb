require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module Omopv4Plus
      class AdmissionDateQueryModifier < QueryModifier

        def self.provided_columns
          [
            :admission_date,
            :discharge_date
          ]
        end

        def self.has_required_columns?(cols)
          cols.map(&:to_s).any? { |col| col =~ /start_date/i }
        end

        def modified_query
          cols = dm.table_cols(source_table).map(&:to_s)
          return query unless cols.any? { |col| col =~ /start_date/i }

          start_col = cols.find { |col| col =~ /start_date/i }.to_sym
          end_col = cols.find { |col| col =~ /end_date/i }.to_sym

          query.from_self(alias: :t)
            .select_all(:t)
            .select_append(Sequel[:t][start_col].as(:admission_date))
            .select_append(Sequel.function(:coalesce, Sequel[:t][end_col], Sequel[:t][start_col]).as(:discharge_date))
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
