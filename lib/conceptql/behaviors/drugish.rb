# frozen_string_literal: true

module ConceptQL
  module Behaviors
    module Drugish
      def self.included(base)
        base.require_column(:drug_name)
        base.require_column(:drug_amount)
        base.require_column(:drug_amount_units)
        base.require_column(:drug_quantity)
        base.require_column(:drug_strength_source_value)
        base.require_column(:drug_days_supply)
        base.require_column(:drug_dose_value)
      end
    end
  end
end
