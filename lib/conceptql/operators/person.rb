# frozen_string_literal: true

require_relative "casting_operator"

module ConceptQL
  module Operators
    class Person < CastingOperator
      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::Timeless

      register __FILE__

      desc "Selects every patient. With one upstream operator, it selects the patients who have a record in the upstream stream."
      returns "One record for each selected patient, from the patients table. The type of the records is person, " \
              "and their start_date and end_date are both the patient's birth date."
      example "All patients", [ "person" ]
      example "The patients with an old myocardial infarction (ICD-9-CM 412)", [ "person", [ "icd9cm", "412" ] ]

      allows_one_upstream
      domains :person

      def my_domain
        :person
      end

      def source_table
        dm.table_by_domain(my_domain)
      end

      def i_point_at
        []
      end

      def these_point_at_me
        # I could list ALL the domains we use, but the default behavior of casting,
        # when there is no explicit casting defined, is to convert everything to
        # person IDs
        #
        # So by defining no known castable relationships in this operator, all
        # domains will be converted to person
        []
      end
    end
  end
end
