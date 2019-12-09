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

        require_column :length_of_stay
        require_column :admission_source
        require_column :discharge_location
      end

      def query(db)
        dm.views.create(db, rdbms)
        db[Sequel["#{collection_type.downcase}_utilizations".to_sym]]
      end

      def collection_type
        raise NotImplementedError
      end

      def available_columns
        %i[
          person_id
          criterion_id
          criterion_table
          start_date
          end_date
          length_of_stay
          admission_source
          discharge_location
          source_value
          source_vocabulary_id
        ].map { |c| [c, Sequel[c]] }.to_h
      end

      def table
        :collections
      end
    end
  end
end
