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

        def where_clause(ds, ctx)
          db = ds.db

          arguments.map do |arg|
            case arg.to_s
            when /^m/i
              Sequel.expr(ctx.primary_table_alias[:gender_concept_id] => male_ids(ds.db))
            when /^f/i
              Sequel.expr(ctx.primary_table_alias[:gender_concept_id] => female_ids(ds.db))
            else
              Sequel.expr(ctx.primary_table_alias[:gender_concept_id] => nil) \
                | Sequel.~(ctx.primary_table_alias[:gender_concept_id] => male_ids(ds.db) + female_ids(ds.db))
            end
          end.inject(&:|)
        end

        def male_ids(db)
          dm.related_concept_ids(db, 8507)
        end

        def female_ids(db)
          dm.related_concept_ids(db, 8532)
        end
      end
    end
  end
end
