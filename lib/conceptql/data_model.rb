require_relative "data_model/generic"
require_relative "data_model/gdm"
require_relative "rdbms"

module ConceptQL
  module DataModel
    def self.for(operator, nodifier)
      case nodifier.data_model
      when :gdm, :gdm
        Gdm.new(operator, nodifier)
      else
        puts "No DataModel defined for #{nodifier.data_model.inspect}, falling back to Generic"
        Generic.new(operator, nodifier)
      end
    end
  end
end
