require_relative "base"

module ConceptQL
  module Operators
    module Binary
      class Filter < Base
        register __FILE__

        desc 'If a result in the left hand results (LHR) has a corresponding result in the right hand results (RHR) with the same person, criterion_id, and criterion_domain, it is passed through.'

        def join_columns
          determine_columns.map{|c| [Sequel[:l][c], Sequel[:r][c]]}
        end

        def where_clause
          nil
        end

        def join_columns
          columns = %w(person_id criterion_id criterion_domain)
          columns += %w(start_date end_date) unless options[:ignore_dates]
          columns.map(&:to_sym)
        end
      end
    end
  end
end
