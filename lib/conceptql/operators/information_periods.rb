# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class InformationPeriods < Operator
      register __FILE__

      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::Timeless

      desc "Selects information periods: the spans of time in which the data has information about a patient, " \
           "such as periods of insurance enrollment."
      argument :information_types, label: "Information Types", type: :codelist,
                                   meaning: "Zero or more information types, each as a concept ID (an integer) " \
                                            "or a concept code of the GDM_INFORMATION_TYPE vocabulary, such as PARTD (Medicare Part D). " \
                                            "A statement may mix both. " \
                                            "With no information types, the operator selects every information period. " \
                                            "With information types, it selects only the information periods whose type is one of them. " \
                                            "An unknown code gets a warning and selects no period."
      returns "One record for each selected information period, from the information_periods table. " \
              "The type of the records is observation_period."
      example "All information periods", [ "information_periods" ]
      domains :observation_period
      category "Get Related Data"
      basic_type :selection
      validate_no_upstreams

      def query(db)
        ds = db[source_table]
        clause = dm.information_period_where_clause(db, arguments)
        ds = ds.where(clause) if clause
        ds
      end

      def source_table
        dm.table_by_domain(domain)
      end

      private

      # A code that names no concept selects no period. A code is known only
      # in its own case, as the lookup finds it. Database#check_codes sorts
      # the codes that the dataset's lexicon does not know, with the 2020
      # rule, as for a vocabulary operator (bead conceptql-dufi). The check
      # reads only the lexicons, so it needs no data database.
      def additional_validation(db, opts = {})
        return unless lexicon_checks?(opts)

        codes = dm.information_type_codes(arguments)
        return if codes.empty?

        not_present, unknown = nodifier.cdb.check_codes(db, dm.information_types_vocab, codes)
        add_warning(Vocabulary::NOT_PRESENT_IN_DATASET, *not_present) unless not_present.empty?
        add_warning(UNKNOWN_CODE, *unknown) unless unknown.empty?
      end
    end
  end
end
