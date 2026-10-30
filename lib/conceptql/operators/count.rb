# frozen_string_literal: true

require_relative "pass_thru"

module ConceptQL
  module Operators
    class Count < PassThru
      register __FILE__

      desc "Counts the number of records that exactly match across all columns."
      # Every stream is a set, so count returns 1 for nearly every row
      # (seed conceptql-e8n, ruled 2026-10-30).
      deprecated "count will become an error in a later release. To count the events of each person, " \
                 'use ["sum", ["numeric", 1, <stream>], {"group_by_person": true}].'
      allows_one_upstream
      validate_one_upstream
      validate_no_arguments
      require_column :value_as_number

      def query_cols
        dynamic_columns - [ :value_as_number ] + [ :value_as_number ]
      end

      def query(db)
        db.from(unioned(db))
          .select_group(*(query_cols - [ :value_as_number ]))
          .select_append { count(1).as(:value_as_number) }
          .from_self
      end

      def unioned(db)
        upstreams.map { |c| c.evaluate(db).select(*query_cols) }.inject do |uni, q|
          uni.union(q.from_self)
        end
      end
    end
  end
end
