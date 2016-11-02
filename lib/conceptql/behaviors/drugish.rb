module ConceptQL
  module Drugish
    def self.included(base)
      base.require_column(:drug_name)
      base.require_column(:drug_amount)
      base.require_column(:drug_amount_units)
      base.require_column(:quantity)
      base.require_column(:days_supply)
      base.query_columns(:drug_exposure, :drug_appendix)
    end
  end
end
