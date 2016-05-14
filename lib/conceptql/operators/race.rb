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
      register __FILE__, :omopv4

      desc 'Generates all person records that match the given set of Race codes.'
      argument :races, type: :codelist, vocab: 'Race'
      domains :person
      category "Select by Property"
      basic_type :selection
      query_columns :person, :concept
      validate_no_upstreams
      validate_at_least_one_argument

      def query(db)
        db.from(:person___p)
          .join(:concept___c, { c__concept_id: :p__race_concept_id })
          .where(Sequel.function(:lower, :c__concept_name) => arguments.map(&:downcase))
      end
    end
  end
end
