# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Hospitalization < Operator
      # GDM only: omopv4_plus has no provenance vocabularies (conceptql-myp).
      register __FILE__, :gdm, :gdm_wide
      include ConceptQL::Behaviors::Utilizable

      desc "Selects admission records of type 'inpatient'"

      def collection_type
        "inpatient"
      end
    end
  end
end
