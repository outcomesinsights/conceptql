# frozen_string_literal: true

require_relative "data_model/gdm"
require_relative "data_model/gdm_wide"
require_relative "rdbms"

module ConceptQL
  module DataModel
    SUPPORTED = %i[gdm gdm_wide].freeze

    # Raised when a caller asks for a data model that ConceptQL does not have.
    class UnsupportedError < ArgumentError
      REMOVED = { omopv4_plus: "0.5.0" }.freeze

      def initialize(data_model)
        message = "ConceptQL has no data model #{data_model.inspect}. Use one of: #{SUPPORTED.join(', ')}."
        if (version = REMOVED[data_model])
          message = "The #{data_model} data model was removed in ConceptQL #{version}. Use one of: #{SUPPORTED.join(', ')}."
        end
        super(message)
      end
    end

    def self.assert_supported!(data_model)
      raise UnsupportedError, data_model unless SUPPORTED.include?(data_model)
    end

    def self.get(data_model, opts = {})
      operator = opts[:operator]
      nodifier = opts[:nodifier]

      case data_model
      when :gdm
        Gdm.new(operator, nodifier)
      when :gdm_wide
        GdmWide.new(operator, nodifier)
      else
        raise UnsupportedError, data_model
      end
    end

    def self.for(operator, nodifier)
      get(nodifier.data_model, nodifier: nodifier, operator: operator)
    end
  end
end
