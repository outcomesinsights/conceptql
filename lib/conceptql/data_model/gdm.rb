require_relative "generic"

module ConceptQL
  module DataModel
    class Gdm < Generic
      def person_table
        :patients
      end

      def query_modifier_for(column)
        {
          place_of_service_concept_id: ConceptQL::QueryModifiers::Gdm::PoSQueryModifier,
          drug_name: ConceptQL::QueryModifiers::Gdm::DrugQueryModifier
        }[column]
      end

      def make_table_id
        :id
      end

      def person_id
        Sequel.expr(:id).as(:person_id)
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

      def person_id_column(query)
        return Sequel.expr(:patient_id).as(:person_id) if query_columns(query).include?(:patient_id)
        return Sequel.expr(:id).as(:person_id) if query_columns(query).include?(:birth_date)
        :person_id
      end

      def data_model
        :oi_cdm
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

      def table_is_missing?(db)
        !db.table_exists?(:concepts)
      end
    end
  end
end
