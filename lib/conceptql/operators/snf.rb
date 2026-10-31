# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Snf < Operator
      register __FILE__
      include ConceptQL::Behaviors::Utilizable

      desc "Selects skilled nursing facility (SNF) admission records."

      def collection_type
        "SNF"
      end
    end
  end
end
