# frozen_string_literal: true

require_relative 'casting_operator'

module ConceptQL
  module Operators
    class Death < CastingOperator
      include ConceptQL::Behaviors::Windowable

      register __FILE__

      desc 'Selects all death records'
      domains :death
      allows_one_upstream

      def my_domain
        :death
      end

      def source_table
        dm.table_by_domain(:death)
      end

      def i_point_at
        [:person]
      end

      def these_point_at_me
        []
      end
    end
  end
end
