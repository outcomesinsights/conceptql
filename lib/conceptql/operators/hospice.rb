# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Hospice < Operator
      register __FILE__
      include ConceptQL::Behaviors::Utilizable

      desc "Selects hospice admission records."

      def collection_type
        "hospice"
      end
    end
  end
end
