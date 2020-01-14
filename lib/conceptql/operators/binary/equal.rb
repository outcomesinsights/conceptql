require_relative "base"

module ConceptQL
  module Operators
    module Binary
      class Equal < Base
        register __FILE__

        desc 'If a result in the left hand results (LHR) has the same value_as_number as a result in the right hand results (RHR), it is passed through.'

        def left
          dm.wrap(super, for: :lab_value_as_number)
        end

        def right
          dm.wrap(super, for: :lab_value_as_number)
        end

        def join_columns
          super | [:lab_value_as_number]
        end

        def where_clause
          {Sequel[:r][:lab_value_as_number] => Sequel[:l][:lab_value_as_number]}
        end
      end
    end
  end
end
