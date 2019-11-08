require_relative "base"

module ConceptQL
  module Operators
    class Hospice < Base
      register __FILE__
      include ConceptQL::Behaviors::Utilizable

      desc "Returns admission records of type 'hospice'"

      def collection_type
        "hospice"
      end
    end
  end
end


