# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Hospitalization < Operator
      register __FILE__
      include ConceptQL::Behaviors::Utilizable

      desc "Selects inpatient admission records."

      def collection_type
        "inpatient"
      end
    end
  end
end
