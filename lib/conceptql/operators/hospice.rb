require_relative "operator"

module ConceptQL
  module Operators
    class Hospice < Operator
      register __FILE__
      include ConceptQL::Behaviors::Utilizable

      desc "Returns admission records of type 'hospice'"

      def collection_type
        "hospice"
      end
    end
  end
end


