require_relative 'operator'
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

      desc "Selects person records that match the given set of Race codes."
      argument :races, type: :codelist, vocab: 'Race'
      domains :person
      category "Select by Property"
      basic_type :selection
      validate_no_upstreams
      validate_at_least_one_argument

      def race_descendents
        @race_descendents ||= YAML.load_file(ConceptQL.race_file)
      end

      def query_cols
        table_columns(table)
      end

      def table
        source_table
      end

      def source_table
        if gdm?
          :patients
        else
          :person
        end
      end

      def query(db)
        words = arguments - actual_ids

        concept_ids = if gdm?
          db[:concepts]
            .where(Sequel.function(:lower, :concept_text) => words.map(&:downcase))
            .select(Sequel[:id].as(:concept_id))
        else
          db[:concept]
            .where(Sequel.function(:lower, :concept_name) => words.map(&:downcase))
            .select(:concept_id)
        end

        c_ids = (concept_ids.from_self.select_map(:concept_id) + actual_ids).map { |i| [i, race_descendents[i]] }.flatten.compact.uniq.sort

        c_ids = dm.related_concept_ids(db,c_ids) if gdm?

        q = db.from(source_table)
        if words.any? { |w| w.match(/unknown/i) }
          c_ids << 0
          q = q.where(race_concept_id: nil)
        end

        q.where(race_concept_id: c_ids)
      end

      def actual_ids
        @actual_ids ||= arguments.select { |i| i.to_s.match(/^\d+$/) }
      end
    end
  end
end
