# frozen_string_literal: true

require_relative "casting_operator"

module ConceptQL
  module Operators
    class Death < CastingOperator
      include ConceptQL::Behaviors::Windowable

      register __FILE__
      effects :select, :cast

      desc "Selects every death record. With one upstream operator, it selects the deaths of the patients who have a record in the upstream stream."
      returns "One record for each selected death, from the deaths table. The type of the records is death, " \
              "and their start_date and end_date are both the date of death."
      example "All death records", [ "death" ]
      example "The deaths of the patients with an old myocardial infarction (ICD-9-CM 412)", [ "death", [ "icd9cm", "412" ] ]
      domains :death

      def my_domain
        :death
      end

      def source_table
        dm.table_by_domain(:death)
      end

      def i_point_at
        [ :person ]
      end

      def these_point_at_me
        []
      end
    end
  end
end
