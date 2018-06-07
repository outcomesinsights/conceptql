require_relative '../conceptql'

module ConceptQL
  # Used to translate a string of terse date adjustments into a set of adjustments that are compatible with most RDBMSs
  class DateAdjuster

    VALID_INPUT = /\A#{Regexp.union([/START/i, /END/i, /\d{4}-\d{2}-\d{2}/, /r?[es]?([-+]?[\ddwmy]+)+/i, /\s*/])}\z/

    attr :op, :str, :manipulator
    def initialize(op, str, opts = {})
      raise "Invalid adjustment string: #{str.pretty_inspect}" unless str.nil? || str =~ VALID_INPUT
      @op = op
      @str = str || ""
      @manipulator = opts[:manipulator] || Sequel
    end

    def adjust(column, reverse=false)
      return Sequel.expr(:end_date) if str.downcase == 'end'
      return Sequel.expr(:start_date) if str.downcase == 'start'
      return op.rdbms.cast_date(Date.parse(str).strftime('%Y-%m-%d')) if str =~ /^\d{4}-\d{2}-\d{2}$/

      origin_column = column

      if str =~ /\Ar/i
        reverse = true
        str.sub!(/\Ar/i, '')
      end

      if (chr = str.chars.first) =~ /S|E/i
        origin_column = if chr.upcase == "E"
                          :end_date
                        else
                          :start_date
                        end
        if column.respond_to?(:qualify)
          origin_column = Sequel.qualify(column.table, origin_column)
        end
        str.sub!(chr, '')
      end

      adjusted_date = adjustments(reverse).inject(Sequel.expr(origin_column)) do |sql, (units, quantity)|
        # Turns out weeks aren't supported in Sequel, so we'll just multiply
        # the number of weeks by 7 and adjust the date by that number of days
        if units == :weeks
          units = :days
          quantity *= 7
        end

        if quantity > 0
          manipulator.date_add(sql, units => quantity)
        else
          manipulator.date_sub(sql, units => quantity.abs)
        end
      end
      op.rdbms.cast_date(adjusted_date)
    end

    # Returns an array of strings that represent date modifiers
    def adjustments(reverse = false)
      @adjustments ||= parse(str, reverse)
    end

    private

    def lookup
      {
        'y' => :years,
        'm' => :months,
        'w' => :weeks,
        'd' => :days
      }
    end

    def parse(str, reverse)
      return [] if str.nil? || str.empty?
      return [[lookup['d'], str.to_i]] if str.match(/^[-+]?\d+$/)
      str.downcase.scan(/([-+]?\d*[dwmy])/).map do |adjustment|
        adjustment = adjustment.first

        quantity = 1
        if adjustment.match(/\d/)
          quantity = adjustment.to_i
        else
          if adjustment.chars.first == '-'
            quantity = -1
          end
        end
        quantity *= -1 if reverse

        unit = lookup[adjustment.chars.last]
        [unit, quantity]
      end
    end
  end
end
