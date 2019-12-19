require_relative "data_model/gdm"
require_relative "rdbms"

module ConceptQL
  module DataModel
    def self.get(data_model, opts = {})
      case data_model
      when :gdm
        Gdm.new(opts)
      else
        raise "No DataModel defined for #{data_model.inspect}"
      end
    end
  end
end
