# frozen_string_literal: true

require_relative 'operator'

module ConceptQL
  module Operators
    class Snf < Operator
      register __FILE__
      include ConceptQL::Behaviors::Utilizable

      desc "Selects admission records of type 'SNF'"

      def collection_type
        'SNF'
      end
    end
  end
end
