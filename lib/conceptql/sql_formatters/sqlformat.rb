require_relative 'formatter'

module ConceptQL
  module SqlFormatters
    class Sqlformat < Formatter
      def program
        "sqlformat"
      end

      def arguments
        %w(
          --reindent
          --use_space_around_operators
          --identifiers lower
          --keywords upper
          -
        )
      end
    end
  end
end


