# frozen_string_literal: true

require_relative 'base'

module ConceptQL
  module DataModel
    class Gdm < Base
      def query_modifier_for(column)
        {
          visit_source_concept_id: ConceptQL::QueryModifiers::Gdm::PoSQueryModifier,
          provider_id: ConceptQL::QueryModifiers::Gdm::ProviderQueryModifier,
          context_specialty_concept_id: ConceptQL::QueryModifiers::Gdm::ProviderQueryModifier,
          drug_name: ConceptQL::QueryModifiers::Gdm::DrugQueryModifier,
          admission_date: ConceptQL::QueryModifiers::Gdm::AdmissionDateQueryModifier,
          provenance_type: ConceptQL::QueryModifiers::Gdm::ProvenanceQueryModifier,
          value_as_number: ConceptQL::QueryModifiers::Gdm::LabQueryModifier
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

      def make_table_id(_table)
        :id
      end

      def fk_by_domain(domain)
        table = table_by_domain(domain)
        "#{table.to_s.gsub(/_id/, '').chomp('s')}_id".to_sym
      end

      def pk_by_domain(_domain)
        :id
      end

      def base
        :gdm
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
        when :collections
          :collections
        else
          :clinical_codes
        end
      end

      def table_to_domain(table)
        {
          patients: :person,
          deaths: :death,
          information_periods: :observation_period,
          practitioners: :provider
        }[table]
      end

      def person_id_column(table)
        col = if table.to_sym == :patients
                :id
              else
                :patient_id
              end
        Sequel.identifier(col).as(:person_id)
      end

      def data_model
        :gdm
      end

      def start_date_column(_query, domain)
        start_date_columns[domain]
      end

      def end_date_column(_query, domain)
        end_date_columns[domain]
      end

      def id_column(_table)
        :id
      end

      def pos_table_fk
        :context_id
      end

      def source_vocabulary_ids
        @source_vocabulary_ids = assign_column_to_table do |table, columns|
          next if %w[patients death].any? { |tn| table.to_s =~ /#{tn}/ }

          reggy = /#{table.to_s.split('_').first}_vocabulary_id/
          column = columns.select { |k| k =~ reggy }.first
          column ||= columns.select { |k| k =~ /_vocabulary_id/ }.first
        end
      end

      def information_period_where_clause(arguments)
        return if arguments.empty?

        { information_type_concept_id: arguments.map(&:to_i) }
      end

      def code_provenance_type(_query, _domain)
        :provenance_concept_id
      end

      def file_provenance_type(_query, _domain)
        :source_type_concept_id
      end

      def file_provenance_types_vocab
        %w[JIGSAW_FILE_PROVENANCE_TYPE JS_FILE_PROV_TYPE]
      end

      def code_provenance_types_vocab
        %w[JIGSAW_CODE_PROVENANCE_TYPE JS_CODE_PROV_TYPE]
      end

      def table_is_missing?(db)
        !(db.table_exists?(:patients) && db.table_exists?(:clinical_codes))
      end
    end
  end
end
