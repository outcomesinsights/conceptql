require_relative "base"

module ConceptQL
  module Operators
    module Binary
      class Match < Base
        register __FILE__

        desc 'If a result in the left hand results (LHR) has a corresponding result in the right hand results (RHR) with the same person, criterion_id, and criterion_domain, it is passed through.'
        default_query_columns

        def query(db)
          join_check = join_clause.inject(&:&)
          sub_select = rhs(db)
            .select(1)
            .where(join_check)

          lhs(db).send(where_method(:where), sub_select.exists).select_all(:l)
        end

        def join_columns
          determine_columns
        end

        def determine_columns
          columns = scope.query_columns | scope.output_columns
          columns &= options[:only_columns].map(&:to_sym) if options[:only_columns]
          columns -= options[:except_columns].map(&:to_sym) if options[:except_columns]
          columns
        end

        def where_method(meth)
          return meth unless invert_match
          meth == :where ? :exclude : :where
        end

        def invert_match
          options[:invert_match]
        end
      end
    end
  end
end

