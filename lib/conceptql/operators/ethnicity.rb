# frozen_string_literal: true

require_relative 'operator'

module ConceptQL
  module Operators
    class Ethnicity < Operator
      register __FILE__

      desc 'Selects person records that match the given set of Ethnicity codes.'
      domains :person
      category 'Select by Property'
      basic_type :selection
      argument :ethnicity, type: :string, options: ['Hispanic or Latino', 'Not Hispanic or Latino']
      validate_no_upstreams
      validate_at_least_one_argument

      def query_cols
        table_columns(table)
      end

      def table
        source_table
      end

      def source_table
        dm.person_table
      end

      def query(db)
        db.from(source_table)
          .where(ethnicity_concept_id: ethnicity_concept_ids)
      end

      def ethnicity_concept_ids
        arguments.map do |words|
          case words
          when /^Not Hispanic/i
            38_003_564
          when /^Hispanic/i
            38_003_563
          when /unknown/i
            [0, nil]
          end
        end.flatten
      end
    end
  end
end
