require_relative 'operator'

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

      desc 'Generates all person records that match the given set of Race codes.'
      argument :races, type: :codelist, vocab: 'Race'
      domains :person
      category "Select by Property"
      basic_type :selection
      validate_no_upstreams
      validate_at_least_one_argument

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
        concept_ids = if gdm?
          db[:concepts]
            .where(Sequel.function(:lower, :concept_text) => arguments.map(&:downcase))
            .select(:id)
        else
          db[:concept]
            .where(Sequel.function(:lower, :concept_name) => arguments.map(&:downcase))
            .select(:concept_id)
        end

        db.from(source_table)
          .where(race_concept_id: concept_ids)
      end
    end
  end
end
