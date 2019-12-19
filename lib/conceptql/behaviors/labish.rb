module ConceptQL
  module Behaviors
    module Labish
      def self.included(base)
        base.output_column :value_as_number
        base.output_column :value_as_string
        base.output_column :value_as_concept_id
        base.output_column :unit_source_value
        base.output_column :range_low
        base.output_column :range_high
      end
    end
  end
end
