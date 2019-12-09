require_relative "base"

module ConceptQL
  module Operators
    class Hospitalization < Base
      register __FILE__
      include ConceptQL::Behaviors::Utilizable

      desc "Returns admission records of type 'inpatient'"

      def collection_type
        "inpatient"
      end
    end
  end
end

