# frozen_string_literal: true

require "sequel"
require "sequel/adapters/mock"
require_relative "../behaviors/labish"

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
        ops(db).first.evaluate(db)
      end

      def domains(db)
        ops.first.domains(db)
      end

      def query_cols
        ops.first.query_cols
      end

      def required_columns
        ops.flat_map(&:required_columns).uniq
      end

      private

      def ops(_db = nil)
        [ ReadGDM.new(nodifier, "read_condition_occurrence", *arguments) ]
      end

      def describe_codes(db, codes)
        ops.flat_map { |op| op.describe_codes(db, codes) }
      end

      class ReadBase < ConceptQL::Operators::Vocabulary
        preferred_name "READ"
        argument :read_codes, type: :codelist, vocab: "Read"
      end

      class ReadGDM < ReadBase
        include ConceptQL::Vocabularies::Behaviors::Gdmish
        include ConceptQL::Behaviors::Labish

        def vocabulary_id
          "Read"
        end

        def domain_map(_v_id)
          :condition_occurrence
        end

        def domains(_db)
          [ :condition_occurrence ]
        end
      end
    end
  end
end
