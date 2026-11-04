# frozen_string_literal: true

require_relative "operator"
require "yaml"

module ConceptQL
  module Operators
    # Represents a operator that will grab all person rows that match the given races
    #
    # Race parameters are passed in as a set of strings.  Each string represents
    # a single race.  The race string must match one of the values in the
    # concept_name column of the concept table.  If you misspell the race name
    # you won't get any matches
    class Race < Operator
      register __FILE__

      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::Timeless

      desc "Selects the patients with the given races."
      argument :races, type: :codelist, vocab: "Race",
                       meaning: "One or more race names, such as White, or race concept IDs. " \
                                "A name matches the concepts with that name in any vocabulary, and case does not matter. " \
                                "The operator also selects the more detailed races under each given race, " \
                                "and each concept that is a kind of one of the race concepts through an is-a relationship. " \
                                "A value that contains Unknown also selects the patients who have no race or race concept ID 0."
      returns "One person record for each patient whose race is one of the given races. " \
              "The start_date and the end_date of each record are the patient's birth date."
      example "All patients recorded as white", [ "race", "White" ]
      domains :person
      category "Select by Property"
      basic_type :selection
      validate_no_upstreams
      validate_at_least_one_argument

      def race_descendents
        @race_descendents ||= YAML.load_file(ConceptQL.race_file)
      end

      def table
        source_table
      end

      def source_table
        :patients
      end

      def query(db)
        words = arguments - actual_ids

        concept_ids = dm.concept_ids_by_name(db, words)

        c_ids = (concept_ids + actual_ids.map(&:to_i)).map { |i| [ i, race_descendents[i] ] }.flatten.compact.uniq.sort

        c_ids = dm.related_concept_ids(db, c_ids)

        condition = Sequel.expr(race_concept_id: c_ids)
        condition = Sequel.|(condition, { race_concept_id: 0 }, { race_concept_id: nil }) if words.any? { |w| w.match(/unknown/i) }

        db.from(source_table).where(condition)
      end

      def actual_ids
        @actual_ids ||= arguments.select { |i| i.to_s.match(/^\d+$/) }
      end
    end
  end
end
