module ConceptQL
  module Operators
    class Invalid < Operator
      register __FILE__, :omopv4

      def annotate_values(db)
        []
      end

      def validate
        @errors = options[:errors]
      end
    end
  end
end
