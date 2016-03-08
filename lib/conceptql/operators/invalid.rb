module ConceptQL
  module Operators
    class Invalid < Operator
      register __FILE__, :omopv4

      default_query_columns

      def initialize(*args)
        super
        @errors = @options.delete(:errors)
      end

      def operator_name
        @operator_name ||= arguments.shift.to_s || "invalid"
      end

      def annotate(db)
        if options[:left] || options[:right]
          options[:left] = to_op(options[:left]).annotate(db) if options[:left]
          options[:right] = to_op(options[:right]).annotate(db) if options[:right]
        end
        super
      end

      def validate(db)
        add_error(*@errors)
      end
    end
  end
end

