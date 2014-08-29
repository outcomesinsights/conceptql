require_relative '../conceptql'

module ConceptQL
  # Used to translate a string of terse date adjustments into a set of adjustments that are compatible with most RDBMSs
  class DateAdjuster
    attr :str
    def initialize(str)
      @str = str
    end

    # Returns an array of strings that represent date modifiers
    def adjustments
      @adjustments ||= parse(str)
    end

    private
    def lookup
      {
        'y' => :years,
        'm' => :months,
        'd' => :days
      }
    end

    def parse(str)
      ConceptQL.logger.debug(str)
      return [] if str.nil? || str.empty?
      return [[lookup['d'], str.to_i]] if str.match(/^[-+]?\d+$/)
      str.downcase.scan(/([-+]?\d*[dmy])/).map do |adjustment|
        adjustment = adjustment.first
        quantity = 1
        if adjustment.match(/\d/)
          quantity = adjustment.to_i
        else
          if adjustment.chars.first == '-'
            quantity = -1
          end
        end
        unit = lookup[adjustment.chars.last]
        [unit, quantity]
      end
    end
  end
end
