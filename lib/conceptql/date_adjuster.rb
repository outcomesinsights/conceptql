require_relative '../conceptql'

module ConceptQL
  # Used to translate a string of terse date adjustments into a set of adjustments that are compatible with most RDBMSs
  class DateAdjuster

    VALID_INPUT = /\A#{Regexp.union([/START/i, /END/i, /\d{4}-\d{2}-\d{2}/, /([-+]?\d+[dmy]?)+/, /\s*/])}\z/

    attr :str, :manipulator
    def initialize(str, opts = {})
      @str = str || ""
      @manipulator = opts[:manipulator] || Sequel
    end

    # Returns an array of strings that represent date modifiers
    def adjustments
      @adjustments ||= parse(str)
    end

    def adjust(column, reverse=false)
      return Sequel.expr(:end_date) if str.downcase == 'end'
      return Sequel.expr(:start_date) if str.downcase == 'start'
      return Sequel.cast(Date.parse(str).strftime('%Y-%m-%d'), Date) if str =~ /^\d{4}-\d{2}-\d{2}$/
      adjusted_date = adjustments.inject(Sequel.expr(column)) do |sql, (units, quantity)|
        quantity *= -1 if reverse
        if quantity > 0
          manipulator.date_add(sql, units => quantity)
        else
          manipulator.date_sub(sql, units => quantity.abs)
        end
      end
      Sequel.cast(adjusted_date, Date)
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
