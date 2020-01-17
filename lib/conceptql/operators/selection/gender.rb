require_relative "base"

module ConceptQL
  module Operators
    module Selection
      class Gender < Base
        register __FILE__

        desc "Returns all person records that match the selected gender."
        argument :gender, type: :string, options: ["Male", "Female", "Unknown"]
        domains :person
        category "Select by Property"
        basic_type :selection
        validate_no_upstreams
        validate_at_least_one_argument

        def where_clause(db)
          arguments.map do |arg|
            case arg.to_s
            when /^m/i
              Sequel.expr(table[:gender_concept_id].name => male_ids(db))
            when /^f/i
              Sequel.expr(table[:gender_concept_id].name => female_ids(db))
            else
              Sequel.|(
                Sequel.expr(table[:gender_concept_id].name => nil),
                Sequel.~(table[:gender_concept_id].name => male_ids(db).union(female_ids(db)))
              )
            end
          end.inject(&:|)
        end

        def male_ids(db)
          lexicon.descendants_of(8507)
        end

        def female_ids(db)
          lexicon.descendants_of(8532)
        end

        def table
          dm.nschema.people_cql
        end
      end
    end
  end
end
