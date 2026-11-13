# frozen_string_literal: true

require_relative "pass_thru"

module ConceptQL
  module Operators
    # Mimics using a variable that has been set via "define" operator
    #
    # The idea is that a concept might be very complex and it helps to break
    # that complex concept into a set of sub-concepts to better understand it.
    #
    # This operator will look for a sub-concept that has been created through the
    # "define" operator and will fetch the records cached in the corresponding table
    class Recall < Operator
      register __FILE__
      effects :refer

      desc "Passes on the records of the operator in the statement that has the given label. " \
           "Use it to break a complex statement into parts, or to use a stream of records more than once."
      returns "The records of the operator that has the given label."
      example 'Label neurological diagnoses as "neuro dxs". Recall them to remove those that were co-reported ' \
              "with a nervous-system MS-DRG. Then apply the one inpatient, two outpatient rule. " \
              "(The code lists are shortened.)",
              [
                "one_in_two_out",
                [
                  "except",
                  {
                    "left" => [
                      "union",
                      [ "icd9", "331.0", "332.0", "340", "345.90" ],
                      [ "icd10cm", "G20", "G30.9", "G35", "G40.909" ],
                      { "label" => "neuro dxs" }
                    ],
                    "right" => [
                      "co_reported",
                      [ "recall", "neuro dxs" ],
                      [ "ms_drg", "056", "057", "058", "059", "060", "100", "101" ]
                    ]
                  }
                ],
                {
                  "outpatient_minimum_gap" => "30d",
                  "outpatient_maximum_gap" => "365d",
                  "outpatient_event_to_return" => "Confirming Event"
                }
              ]

      argument :name, type: :string,
                      meaning: "The label of the operator whose records to pass on. It must match the label exactly, " \
                               "including case. The labeled operator can come before or after the recall in the " \
                               "statement, but labeled streams that recall each other in a loop are invalid."
      category "Get Related Data"
      diagram_base :selection
      validate_no_upstreams
      validate_one_argument
      default_query_columns

      def query(db)
        scope.from(db, source)
      end

      def domains(db)
        scope.domains(source, db)
      end

      def source
        arguments.first
      end

      def annotate(db, opts = {})
        @annotate ||= if valid?(db) && replaced?
                        original.annotate(db, opts)
        else
                        super
        end
      end

      def original
        nodifier.scope.fetch_operator(source)
      end

      # The input of a recall is the labeled operator.
      def no_records_in_data?(db, opts = {})
        valid?(db, opts) && original.no_records_in_data?(db, opts)
      end

      def code_list(db)
        original.code_list(db)
      end

      private

      def additional_validation(_db, _opts = {})
        return unless arguments.length == 1

        if scope.fetch_operator(source)
          scope.recall_dependencies[source].each do |d|
            add_error("mutually referential recalls", d) if scope.recall_dependencies[d].include?(source)
          end
        else
          add_error("no matching label", source)
        end
      end

      def replaced?
        options[:replaced]
      end
    end
  end
end
