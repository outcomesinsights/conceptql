require_relative "data_model/omopv4_plus"
require_relative "data_model/gdm"
require_relative "rdbms"

module ConceptQL
  module DataModel
    def self.for(operator, nodifier)
      case nodifier.data_model
      when :gdm
        Gdm.new(operator, nodifier)
      when :omopv4_plus
        Omopv4Plus.new(operator, nodifier)
      else
        raise "No DataModel defined for #{nodifier.data_model.inspect}"
      end
    end
  end
end
