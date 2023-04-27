require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Sum < PassThru
      register __FILE__

      desc <<-EOF
Sums value_as_number across all records that match on all but start_date, end_date.
For start_date and end_date the min and max of each respectively is returned.'
      EOF
      default_query_columns
      validate_at_least_one_upstream
      validate_no_arguments
      require_column :value_as_number

      def query(db)
        db.from(unioned(db))
          .select_group(*(dynamic_columns - [:start_date, :end_date, :criterion_id, :value_as_number]))
          .select_append(Sequel.lit('?', 0).as(:criterion_id))
          .select_append{ min(start_date).as(:start_date) }
          .select_append{ max(end_date).as(:end_date) }
          .select_append{sum(value_as_number).as(:value_as_number)}
          .from_self
      end

      def unioned(db)
        upstreams.map { |c| c.evaluate(db).select(*query_cols) }.inject do |uni, q|
          uni.union(q)
        end
      end
    end
  end
end

