require 'sequel'
require 'sequel/adapters/mock'
require_relative "condition_occurrence_source_vocabulary_operator"
require_relative "source_vocabulary_operator"
require_relative "vocabulary"
require_relative '../behaviors/labish'
require "byebug"

module ConceptQL
  module Operators
    class Read < Operator
      register __FILE__

      preferred_name "READ"
      desc "Selects results from the the condition_occurrence, procedure_occurrence, drug_exposure, and observation tables based on the READ codes provided."
      argument :read_codes, type: :codelist, vocab: "Read"
      basic_type :selection
      category "Select by Clinical Codes"

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
        gdm? ? vocab_op.domains(db) : codes_by_domain(db).keys
      end

      def query_cols
        gdm? ? ops.first.query_cols : vocab_op.query_cols
      end

      def required_columns
        ops.flat_map(&:required_columns).uniq
      end

      private

      def ops(db = nil)
        if gdm?
          [ReadGDM.new(self.nodifier, "read_condition_occurrence", *arguments)]
        else
          codes_by_domain(db).map do |domain, codes|
            klasses[domain].new(self.nodifier, "read_#{domain}", *codes)
          end
        end
      end

      def codes_by_domain(db)
        if no_db?(db)
          if lexicon
            @no_db_codes_by_domain ||= lexicon.codes_by_domain(arguments, "READ")
            return @no_db_codes_by_domain
          end
          return { observation: arguments }
        end
        @codes_by_domain ||= get_codes_by_domain(db)
      end

      def get_codes_by_domain(db)
        codes_and_mapping_types = db[:source_to_concept_map]
          .where(source_code: arguments, source_vocabulary_id: 17)
          .select_map([:source_code, :mapping_type])

        doms_and_codes = codes_and_mapping_types.group_by(&:last).each_with_object({}) do |(mapping_type, codes_and_maps), doms|
          dom = mapping_type_to_domain(mapping_type)
          doms[dom] ||= []
          doms[dom] += codes_and_maps.map(&:first)
        end

        leftovers = arguments - doms_and_codes.flat_map { |k, v| v }
        unless leftovers.empty?
          doms_and_codes[:observation] ||= []
          doms_and_codes[:observation] += leftovers
        end
        doms_and_codes
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

      class ReadGDM < ConditionOccurrenceSourceVocabularyOperator
        preferred_name "READ"
        argument :read_codes, type: :codelist, vocab: "Read"

        include ConceptQL::Labish

        def vocabulary_id
          17
        end
      end

      class ReadCondition < ConditionOccurrenceSourceVocabularyOperator
        preferred_name "READ"
        argument :read_codes, type: :codelist, vocab: "Read"

        def vocabulary_id
          17
        end
      end

      class ReadProcedure < SourceVocabularyOperator
        preferred_name "READ"
        argument :read_codes, type: :codelist, vocab: "Read"

        def table
          :procedure_occurrence
        end

        def vocabulary_id
          17
        end

        def source_column
          :procedure_source_value
        end

        def concept_column
          :procedure_concept_id
        end
      end

      class ReadObservation < SourceVocabularyOperator
        preferred_name "READ"
        argument :read_codes, type: :codelist, vocab: "Read"

        def table
          :observation
        end

        def vocabulary_id
          17
        end

        def source_column
          :observation_source_value
        end

        def concept_column
          :observation_concept_id
        end
      end

      class ReadDrug < SourceVocabularyOperator
        preferred_name "READ"
        argument :read_codes, type: :codelist, vocab: "Read"

        def table
          :drug_exposure
        end

        def vocabulary_id
          17
        end

        def source_column
          :drug_source_value
        end

        def concept_column
          :drug_concept_id
        end
      end

      def vocab_op
        @vocab_op ||= Vocabulary.new(nodifier, *values, vocabulary: "Read")
      end
    end
  end
end
