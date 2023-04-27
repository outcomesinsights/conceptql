require_relative 'pass_thru'

module ConceptQL
  module Operators
    # Mimics using a variable that has been set via "define" operator
    #
    # The idea is that a concept might be very complex and it helps to break
    # that complex concept into a set of sub-concepts to better understand it.
    #
    # This operator will look for a sub-concept that has been created through the
    # "define" operator and will fetch the records cached in the corresponding table
    class Recall < Operator
      register __FILE__

      desc <<-EOF
Recalls a set of named records that were previously stored using the Define operator.
Must be surrounded by the same Let operator as surrounds the corresponding Define operator.
      EOF
      argument :name, type: :string
      category "Get Related Data"
      basic_type :selection
      validate_no_upstreams
      validate_one_argument
      default_query_columns

      def query(db)
        scope.from(db, source)
      end

      def domains(db)
        scope.domains(source, db)
      end

      def source
        arguments.first
      end

      def annotate(db, opts = {})
        @annotate ||= if valid?(db) && replaced?
          original.annotate(db, opts)
        else
          super
        end
      end

      def original
        nodifier.scope.fetch_operator(source)
      end

      def code_list(db)
        original.code_list(db)
      end

      private

      def additional_validation(db, opts = {})
        if arguments.length == 1
          if scope.fetch_operator(source)
            scope.recall_dependencies[source].each do |d|
              if scope.recall_dependencies[d].include?(source)
                add_error("mutually referential recalls", d)
              end
            end
          else
            add_error("no matching label", source)
          end
        end
      end

      def replaced?
        options[:replaced]
      end
    end
  end
end

