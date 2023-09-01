require 'sequel'
require 'sequel/adapters/mock'
require_relative '../behaviors/labish'

module ConceptQL
  module Operators
    class Read < Operator
      include ConceptQL::Behaviors::CodeLister
      register __FILE__

      preferred_name "READ"
      desc "Selects records based on the Read vocabulary."
      argument :read_codes, type: :codelist, vocab: "Read"
      basic_type :selection
      category "Select by Clinical Codes"
      conceptql_spec_id "vocabulary"

      def query(db)
        gdm? ? gdm(db) : omopv4(db)
      end

      def gdm(db)
        ops(db).first.evaluate(db)
      end

      def omopv4(db)
        streams = ops(db).map { |op| op.evaluate(db) }

        streams.inject { |q, query| q.union(query, all: true) }.from_self
      end

      def domains(db)
        ops.first.domains(db)
      end

      def query_cols
        gdm? ? ops.first.query_cols : ops.map(&:query_cols).flatten.uniq
      end

      def required_columns
        ops.flat_map(&:required_columns).uniq
      end

      private

      def ops(db = nil)
        [ReadGDM.new(self.nodifier, "read_condition_occurrence", *arguments)]
      end

      def describe_codes(db, codes)
        ops.flat_map { |op| op.describe_codes(db, codes) }
      end


      def mapping_type_to_domain(mapping_type)
        case mapping_type.to_s
        when /cond/i
          :condition_occurrence
        when /proc/i
          :procedure_occurrence
        when /drug/i
          :drug_exposure
        else
          :observation
        end
      end

      def klasses
        @klasses ||= {
          condition_occurrence: ReadCondition,
          procedure_occurrence: ReadProcedure,
          drug_exposure: ReadDrug,
          observation: ReadObservation
        }
      end

      class ReadBase < ConceptQL::Operators::Vocabulary
        preferred_name "READ"
        argument :read_codes, type: :codelist, vocab: "Read"
      end

      class ReadOmopBase < ReadBase
        include ConceptQL::Vocabularies::Behaviors::Omopish
        include ConceptQL::Vocabularies::Behaviors::Sourcish

        def vocabulary_id
          17
        end

        def source_table
          table
        end

        def domain
          table
        end

        def domains(db)
          Array(domain)
        end
      end

      class ReadGDM < ReadBase
        include ConceptQL::Vocabularies::Behaviors::Gdmish
        include ConceptQL::Behaviors::Labish

        def vocabulary_id
          "Read"
        end

        def domain_map(v_id)
          :condition_occurrence
        end

        def domains(db)
          [:condition_occurrence]
        end
      end

      class ReadCondition < ReadOmopBase
        def table
          :procedure_occurrence
        end

        def source_column
          :procedure_source_value
        end

        def concept_column
          :procedure_concept_id
        end
      end

      class ReadProcedure < ReadOmopBase
        def table
          :procedure_occurrence
        end

        def source_column
          :procedure_source_value
        end

        def concept_column
          :procedure_concept_id
        end
      end

      class ReadObservation < ReadOmopBase
        include ConceptQL::Behaviors::Labish

        def table
          :observation
        end

        def source_column
          :observation_source_value
        end

        def concept_column
          :observation_concept_id
        end
      end

      class ReadDrug < ReadOmopBase
        include ConceptQL::Behaviors::Drugish

        def table
          :drug_exposure
        end

        def source_column
          :drug_source_value
        end

        def concept_column
          :drug_concept_id
        end
      end
    end
  end
end
