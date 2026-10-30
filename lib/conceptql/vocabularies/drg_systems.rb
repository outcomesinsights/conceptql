# frozen_string_literal: true

require "date"

module ConceptQL
  module Vocabularies
    # The two DRG systems and their operators, ms_drg and cms_drg (bead
    # conceptql-alw, seed conceptql-7p3).
    #
    # CMS replaced the CMS-DRG system with MS-DRG on 2007-10-01 and reused
    # most DRG codes for new meanings: DRG 010 meant "Nervous System
    # Neoplasms" before that day and "Pancreas transplant" after it. One
    # vocabulary, DRG, holds both systems, and an event row does not record
    # which meaning applied: the ETL stores one concept ID for each source code
    # whatever the event date. So a statement names the system, and the system
    # decides by the event date. ["ms_drg", "010"] selects the DRG 010 events
    # from 2007-10-01, and ["cms_drg", "010"] selects the DRG 010 events before
    # that day. The concept-ID lookup is the one that drg uses, so the
    # operators work with the OHDSI and the GDM lexicons alike. They use no
    # OHDSI validity date and no concept class to select events.
    #
    # Each operator is a vocabulary operator of vocabulary DRG. So its code
    # format is the DRG row of vocabulary_formats (a vocabulary operator uses
    # the row of the vocabulary it selects), and its unknown-code warning
    # checks the DRG vocabulary.
    #
    # The deprecated drg operator selects the events of both systems.
    module DrgSystems
      # The first day of MS-DRG. ms_drg selects the events on or after this
      # day, and cms_drg the events before it.
      MS_DRG_START_DATE = Date.new(2007, 10, 1)

      # The vocabulary and the operator that hold both systems.
      VOCABULARY_ID = "DRG"
      DRG_OPERATOR = "drg"

      DRG_DEPRECATION = "drg will become an error in a later release. A DRG code can have two meanings, " \
                        "and drg selects the events of both. Use ms_drg for the MS-DRG meaning (events from " \
                        "#{MS_DRG_START_DATE.iso8601}) or cms_drg for the CMS-DRG meaning (events before " \
                        "#{MS_DRG_START_DATE.iso8601}).".freeze

      # operator: the operator name. concept_class_id: the OHDSI concept class
      # of the system's meanings. from_cutover: true when the system starts on
      # MS_DRG_START_DATE, false when it ends the day before.
      System = Data.define(:operator, :name, :long_name, :concept_class_id, :from_cutover) do
        # The condition on the event's start date.
        def date_condition(start_date_column)
          column = Sequel.identifier(start_date_column)
          from_cutover ? column >= MS_DRG_START_DATE : column < MS_DRG_START_DATE
        end
      end

      SYSTEMS = [
        System.new(operator: "ms_drg", name: "MS-DRG",
                   long_name: "Medicare Severity Diagnosis-Related Group (CMS), events from " \
                              "#{MS_DRG_START_DATE.iso8601}",
                   concept_class_id: "MS-DRG", from_cutover: true),
        System.new(operator: "cms_drg", name: "CMS-DRG",
                   long_name: "CMS Diagnosis-Related Group, events before #{MS_DRG_START_DATE.iso8601}",
                   concept_class_id: "DRG", from_cutover: false)
      ].to_h { |system| [ system.operator, system ] }.freeze

      class << self
        def system(operator)
          SYSTEMS[operator]
        end

        # The vocabulary entries of ms_drg and cms_drg, as id => Entry. Each
        # copies the entry of drg (its domain, for example) and renames it.
        # Without a drg entry there is none.
        def entries(drg_entry)
          return {} unless drg_entry

          SYSTEMS.transform_values do |system|
            drg_entry.merge(Entry.new(id: system.operator,
                                      omopv5_vocabulary_id: VOCABULARY_ID,
                                      preferred_name: system.name,
                                      vocabulary_short_name: system.name,
                                      vocabulary_long_name: system.long_name))
          end
        end
      end

      # The behavior of the ms_drg and cms_drg operator classes.
      module OperatorBehavior
        def drg_system
          DrgSystems.system(vocab_entry.id)
        end

        # Each code is named by its meaning in the operator's system when the
        # lexicon can tell: the OHDSI vocabulary gives each meaning a concept
        # class (MS-DRG or DRG). A code without a row of that class, and every
        # code under a lexicon that keeps no class (GDM), gets every name of
        # the code, as drg gives.
        def describe_codes(db, codes)
          return super if select_all?

          in_system = dm.concepts_to_codes_in_class(db, vocabulary_id, drg_system.concept_class_id, codes)
          return super if in_system.blank?

          named = in_system.map { |code, _| code.downcase }
          rest = codes.reject { |code| named.include?(code.downcase) }
          in_system + (rest.empty? ? [] : super(db, rest))
        end

        # The operator selects one meaning of each code, so a code that the
        # vocabulary reused across the two systems needs no warning.
        def warn_about_reused_codes(_db, _codes); end

        private

        def where_clause(db)
          Sequel.&(super, drg_system.date_condition(dm.start_date_column(db, criterion_table)))
        end
      end
    end
  end
end
