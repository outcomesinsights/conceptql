require_relative "data_model/generic"
require_relative "data_model/gdm"
module ConceptQL
  module DataModel
    def self.for(operator, nodifier)
      case nodifier.data_model
      when :oi_cdm, :gdm
        Gdm.new(operator, nodifier)
      else
        puts "No DataModel defined for #{nodifier.data_model.inspect}, falling back to Generic"
        Generic.new(operator, nodifier)
      end
    end
  end
end
