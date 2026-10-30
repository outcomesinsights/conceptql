# frozen_string_literal: true

module ConceptQL
  module Operators
    class Invalid < Operator
      register __FILE__

      no_desc
      default_query_columns

      # The statement [nil] or [""] has no operator name. It is named
      # "invalid", as an empty statement is, so it does not report its error
      # under the key "" (bead conceptql-1ci).
      def initialize(*args)
        super
        @op_name = "invalid" if op_name.to_s.empty?
        @errors = @options.delete(:errors)
      end

      # The name in the statement. Operator#operator_name would give the class
      # name, "invalid", for every unknown operator.
      def operator_name
        op_name
      end

      def query(_db)
        raise "Invalid#query called.  #{errors}"
      end

      def annotate(db, opts = {})
        if options[:left] || options[:right]
          options[:left] = to_op(options[:left]).annotate(db, opts) if options[:left]
          options[:right] = to_op(options[:right]).annotate(db, opts) if options[:right]
        end
        super
      end

      def validate(db, opts = {}); end
    end
  end
end
