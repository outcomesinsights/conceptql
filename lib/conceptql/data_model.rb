require_relative "data_model/omopv4_plus"
require_relative "data_model/gdm"
require_relative "rdbms"

module ConceptQL
  module DataModel
    def self.get(data_model, opts = {})
      operator = opts[:operator]
      nodifier = opts[:nodifier]

      case data_model
      when :gdm
        Gdm.new(operator, nodifier)
      when :omopv4_plus
        Omopv4Plus.new(operator, nodifier)
      else
        raise "No DataModel defined for #{data_model.inspect}"
      end
    end

    def self.for(operator, nodifier)
      get(nodifier.data_model, nodifier: nodifier, operator: operator)
    end
  end
end
