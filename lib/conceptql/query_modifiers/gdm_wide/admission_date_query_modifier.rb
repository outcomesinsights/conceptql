# frozen_string_literal: true

require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module GdmWide
      class AdmissionDateQueryModifier < QueryModifier
        def self.provided_columns
          %i[
            admission_date
            discharge_date
          ]
        end

        def self.has_required_columns?(cols)
          needed = %i[admit_admission_date admit_discharge_date].sort
          found = needed & cols
          needed == found
        end

        def modified_query
          return query unless dm.table_cols(source_table).include?(:admit_admission_date)

          query.from_self
               .select_append(Sequel.function(:coalesce, :admit_admission_date, :start_date).as(:admission_date))
               .select_append(Sequel.function(:coalesce, :admit_discharge_date, :end_date,
                                              :start_date).as(:discharge_date))
               .from_self
        end

        private

        def domain
          op.domain
        rescue StandardError
          nil
        end
      end
    end
  end
end
