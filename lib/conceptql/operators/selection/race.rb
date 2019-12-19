require_relative "base"
require "yaml"

module ConceptQL
  module Operators
    module Selection
      # Represents a operator that will grab all person rows that match the given races
      #
      # Race parameters are passed in as a set of strings.  Each string represents
      # a single race.  The race string must match one of the values in the
      # concept_name column of the concept table.  If you misspell the race name
      # you won't get any matches
      class Race < Base
        register __FILE__

        desc 'Generates all person records that match the given set of Race codes.'
        argument :races, type: :codelist, vocab: 'Race'
        domains :person
        category "Select by Property"
        basic_type :selection
        validate_no_upstreams
        validate_at_least_one_argument

        def where_clause(db)
          words = arguments - actual_ids

          # TODO: Update this to find descendants from Lexicon
          concept_ids = db[:concepts]
            .where(Sequel.function(:lower, :concept_text) => words.map(&:downcase))
            .select(Sequel[:id].as(:concept_id))

          c_ids = concept_ids.from_self.select_map(:concept_id) + actual_ids

          c_ids = lexicon.descendants_of(*c_ids).select_map(:descendant_id)

          where = { race_concept_id: c_ids }

          if words.any? { |w| w.match(/unknown/i) }
            c_ids << 0
            Sequel[where].|(race_concept_id: nil)
          end

          where
        end

        def table
          dm.nschema.people_cql
        end

        def actual_ids
          @actual_ids ||= arguments.select { |i| i.to_s.match(/^\d+$/) }
        end
      end
    end
  end
end
