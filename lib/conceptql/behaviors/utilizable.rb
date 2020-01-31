require "active_support/concern"
require_relative "windowable"

module ConceptQL
  module Behaviors
    module Utilizable
      extend ActiveSupport::Concern
      include ConceptQL::Behaviors::Windowable

      included do
        domains :condition_occurrence
        category "Select by Property"
        basic_type :selection
        validate_no_upstreams
        validate_no_arguments

        output_column :admission_date
        output_column :discharge_date
        output_column :length_of_stay
        output_column :admission_source_value
        output_column :admission_source_description
        output_column :discharge_location_source_value
        output_column :discharge_location_source_description
      end

      def query(db)
        ds = db[table_name]
        prepare_columns(ds)
      end

      def table
        dm.nschema[table_name]
      end

      def collection_type
        raise NotImplementedError
      end

      def table_name
        "#{collection_type.downcase}_utilizations_v1".to_sym
      end
    end
  end
end
