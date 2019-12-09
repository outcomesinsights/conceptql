require_relative "base"

module ConceptQL
  module Operators
    class Snf < Base
      register __FILE__
      include ConceptQL::Behaviors::Utilizable

      desc "Returns admission records of type 'SNF'"

      def collection_type
        "SNF"
      end
    end
  end
end

