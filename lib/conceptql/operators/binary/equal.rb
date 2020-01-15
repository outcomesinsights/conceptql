require_relative "base"

module ConceptQL
  module Operators
    module Binary
      class Equal < Base
        register __FILE__

        desc 'If a result in the left hand results (LHR) has the same value_as_number as a result in the right hand results (RHR), it is passed through.'

        def lhs(db, opts = {})
          dm.wrap(super, for: :lab_value_as_number)
            .auto_select(required_columns: required_columns_for_upstream)
        end

        def rhs(db, opts = {})
          dm.wrap(super, for: :lab_value_as_number)
            .auto_select(required_columns: join_columns)
        end

        def join_columns
          super | %i[criterion_id criterion_table lab_value_as_number]
        end

        def where_clause
          {Sequel[:r][:lab_value_as_number] => Sequel[:l][:lab_value_as_number]}
        end
      end
    end
  end
end
