require_relative "omopv4_plus"

module ConceptQL
  module DataModel
    class Gdm < Omopv4Plus
      def person_table
        :patients
      end

      def query_modifier_for(column)
        {
          place_of_service_concept_id: ConceptQL::QueryModifiers::Gdm::PoSQueryModifier,
          provider_id: ConceptQL::QueryModifiers::Gdm::ProviderQueryModifier,
          drug_name: ConceptQL::QueryModifiers::Gdm::DrugQueryModifier,
          provenance_type: ConceptQL::QueryModifiers::Gdm::ProvenanceQueryModifier,
        }[column]
      end

      def make_table_id
        :id
      end

      def person_id(table = nil)
        return :id if table == :patients
        :patient_id
      end

      def person_table
        :patients
      end

      def period_table
        :information_periods
      end

      def criterion_id
        Sequel.expr(:id).as(:criterion_id)
      end

      def table_id(table = nil)
        return :criterion_id if table.nil?
        Sequel.expr(make_table_id(table)).as(:criterion_id)
      end

      def make_table_id(table)
        :id
      end

      def fk_by_domain(domain)
        table = table_by_domain(domain)
        (table.to_s.gsub(/_id/, "").chomp("s") + "_id").to_sym
      end

      def pk_by_domain(domain)
        :id
      end

      def table_by_domain(table)
        return nil unless table
        case table
        when :person, :patients
          :patients
        when :death, :deaths
          :deaths
        when :observation_period, :information_periods
          :information_periods
        when :provider, :practitioners
          :practitioners
        else
          :clinical_codes
        end
      end

      def person_id_column(table)
        col = if table.to_sym == :patients
          :id
        else
          :patient_id
        end
        Sequel.identifier(col).as(:person_id)
      end
=begin
      def person_id_column(query)
        return Sequel.expr(:patient_id).as(:person_id) if query_columns(query).include?(:patient_id)
        return Sequel.expr(:id).as(:person_id) if query_columns(query).include?(:birth_date)
        :person_id
      end
=end

      def data_model
        :gdm
      end

      def start_date_column(query, domain)
        start_date_columns[domain]
      end

      def end_date_column(query, domain)
        end_date_columns[domain]
      end

      def id_column(table)
        :id
      end

      def pos_table_fk
        :context_id
      end

      # The mappings table will tell us what other concepts have been directly
      # mapped to the concepts passed in
      def related_concept_ids(db, *ids)
        other_ids = db[:mappings].where(concept_id_2: ids).where(relationship_id: "IS_A").select_map(:concept_id_1)
        other_ids + ids
      end

      def table_is_missing?(db)
        !db.table_exists?(:concepts)
      end

      def provenance_type_column(query, domain)
        :provenance_concept_id
      end
    end
  end
end
