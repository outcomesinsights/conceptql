module ConceptQL
  module Behaviors
    module Labish
      def self.included(base)
        base.require_column :value_as_number
        base.require_column :value_as_string
        base.require_column :value_as_concept_id
        base.require_column :unit_source_value
        base.require_column :range_low
        base.require_column :range_high
      end
    end
  end
end
