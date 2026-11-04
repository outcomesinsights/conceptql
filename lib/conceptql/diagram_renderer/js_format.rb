# frozen_string_literal: true

module ConceptQL
  module DiagramRenderer
    # The JavaScript rules that the ported renderer code depends on: how a value
    # becomes a string (String(value), template literals, Array#join), which
    # values are falsy, and the order of Object.entries. The JavaScript renderer
    # builds path strings and labels with these rules, so the Ruby port must use
    # them to produce the same strings.
    module JsFormat
      module_function

      # Number::toString (ECMAScript 6.1.6.1.20) for a finite or non-finite
      # number: 100.0 is "100", 1.0e-7 is "1e-7", -0.0 is "0".
      def number(value)
        return value.to_s if value.is_a?(Integer)

        value = Float(value)
        return "NaN" if value.nan?
        return value.positive? ? "Infinity" : "-Infinity" if value.infinite?
        return "0" if value.zero?
        return "-#{number(-value)}" if value.negative?

        digits, n = shortest_digits(value)
        k = digits.length
        if k <= n && n <= 21
          digits + ("0" * (n - k))
        elsif n.positive? && n <= 21
          "#{digits[0, n]}.#{digits[n..]}"
        elsif n > -6 && n <= 0
          "0.#{'0' * -n}#{digits}"
        else
          exponent = n - 1
          sign = exponent.negative? ? "-" : "+"
          mantissa = k == 1 ? digits : "#{digits[0]}.#{digits[1..]}"
          "#{mantissa}e#{sign}#{exponent.abs}"
        end
      end

      # String(value) for a JSON value.
      def string(value)
        case value
        when nil then "null"
        when String then value
        when Numeric then number(value)
        when Array then join(value, ",")
        when Hash then "[object Object]"
        else value.to_s
        end
      end

      # Array.prototype.join: null elements become "".
      def join(array, separator)
        array.map { _1.nil? ? "" : string(_1) }.join(separator)
      end

      # JavaScript truthiness for a JSON value.
      def truthy?(value)
        case value
        when nil, false then false
        when String then !value.empty?
        when Float then !(value.zero? || value.nan?)
        when Integer then !value.zero?
        else true
        end
      end

      # The length of a value as JavaScript reads `value.length`, for the
      # comparisons in geometry.js: a string's or an array's length, otherwise
      # NaN (JavaScript's undefined, which compares false with every number).
      #
      # A string's length counts characters (code points). JavaScript counts
      # UTF-16 code units, so a character outside the Basic Multilingual Plane
      # (an emoji) counts 1 here and 2 in JavaScript.
      def length(value)
        value.is_a?(String) || value.is_a?(Array) ? value.length : Float::NAN
      end

      # Object.entries order for a JSON object: integer-like keys first, in
      # numeric order, then the other keys in insertion order.
      def entries(hash)
        index, other = hash.partition { |key, _| array_index?(key) }
        index.sort_by { |key, _| key.to_i } + other
      end

      # String.prototype.trimEnd: the JavaScript WhiteSpace and LineTerminator
      # characters.
      TRAILING_WHITESPACE = /[\t\n\v\f\r    -     　﻿]+\z/

      def trim_end(text) = text.sub(TRAILING_WHITESPACE, "")

      # The shortest decimal digits that round-trip to `value` (positive,
      # finite), and the exponent n of ECMAScript's definition: value is
      # 0.<digits> x 10^n. Ruby's Float#to_s prints the same shortest digits.
      def shortest_digits(value)
        mantissa, exponent = value.to_s.split("e")
        whole, fraction = mantissa.split(".")
        digits = whole + fraction.to_s
        n = whole.length + exponent.to_i
        stripped = digits.sub(/\A0+/, "")
        n -= digits.length - stripped.length
        [ stripped.sub(/0+\z/, ""), n ]
      end

      def array_index?(key)
        key.is_a?(String) && key.match?(/\A(?:0|[1-9]\d*)\z/) && key.to_i < 4_294_967_295
      end

      private_class_method :shortest_digits, :array_index?
    end
  end
end
