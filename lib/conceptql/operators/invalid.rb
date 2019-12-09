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

      def operator_name
        @operator_name ||= arguments.shift.to_s || "invalid"
      end

      def query(db)
        raise "Invalid#query called.  #{errors}"
      end

      def annotate(db, opts = {})
        if options[:left] || options[:right]
          options[:left] = to_op(options[:left]).annotate(db, opts) if options[:left]
          options[:right] = to_op(options[:right]).annotate(db, opts) if options[:right]
        end
        super
      end

      def validate(db, opts = {})
      end
    end
  end
end

