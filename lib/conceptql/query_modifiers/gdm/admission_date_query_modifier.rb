require_relative '../query_modifier'

module ConceptQL
  module QueryModifiers
    module Gdm
      class AdmissionDateQueryModifier < QueryModifier

        def self.provided_columns
          [
            :admission_date,
            :discharge_date
          ]
        end

        def self.has_required_columns?(cols)
          needed = [:collection_id].sort
          found = needed & cols
          needed == found
        end

        def modified_query
          return query unless dm.table_cols(source_table).include?(:collection_id)
          query.from_self(alias: :cc)
            .left_join(:collections, Sequel[:cc][:collection_id] => Sequel[:co][:id], table_alias: :co)
            .left_join(:admission_details, Sequel[:co][:admission_detail_id] => Sequel[:ad][:id], table_alias: :ad)
            .select_all(:cc)
            .select_append(Sequel.function(:coalesce, Sequel[:ad][:admission_date], Sequel[:cc][:start_date]).as(:admission_date))
            .select_append(Sequel.function(:coalesce, Sequel[:ad][:discharge_date], Sequel[:cc][:end_date], Sequel[:cc][:start_date]).as(:discharge_date))
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
