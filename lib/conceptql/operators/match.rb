# frozen_string_literal: true

require_relative 'binary_operator_operator'

module ConceptQL
  module Operators
    class Match < BinaryOperatorOperator
      register __FILE__

      desc 'Keeps left hand records that share the same person, criterion_id, and criterion_domain with a right hand side record.'
      default_query_columns

      def query(db)
        rhs = right.evaluate(db)
        rhs = rhs.from_self.select_group(*columns)
        query = db.from(Sequel.as(left.evaluate(db), :l))

        join_check = join_columns.inject(&:&)
        sub_select = rhs.from_self(alias: :r)
                        .select(1)
                        .where(join_check)

        query.send(where_method(:where), sub_select.exists).select_all(:l)
      end

      def columns
        @columns ||= determine_columns
      end

      def join_columns_option
        columns
      end

      def determine_columns
        columns = dynamic_columns
        columns &= options[:only_columns].map(&:to_sym) if options[:only_columns]
        columns -= options[:except_columns].map(&:to_sym) if options[:except_columns]
        columns
      end

      def where_method(meth)
        return meth unless invert_match

        meth == :where ? :exclude : :where
      end

      def invert_match
        options[:invert_match]
      end
    end
  end
end
