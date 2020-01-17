require_relative "base"

module ConceptQL
  module Operators
    class Invalid < Base
      register __FILE__

      no_desc
      default_query_columns

      def initialize(*args)
        super
        @errors = @options.delete(:errors)
      end

      def query(db)
        raise "Invalid#query called.  #{errors}"
      end

      def annotate(db, opts = {})
        if options[:left]
          left = to_op(options[:left])
          left.required_columns = required_columns_for_upstream
          options[:left] = left.annotate(db, opts)
        end

        if options[:right]
          right = to_op(options[:right])
          right.required_columns = required_columns_for_upstream
          options[:right] = right.annotate(db, opts)
        end
        super
      end

      def validate(db, opts = {})
      end
    end
  end
end

