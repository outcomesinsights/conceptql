# frozen_string_literal: true

require "json"

# Writes JSON in the layout `just fmt` (prettier, on its defaults) gives it, so a
# results file the suite writes is already formatted. The Docker test image has no
# prettier, so the suite cannot run it. prettier_json_test.rb checks this against
# every tracked results file.
#
# The rules, from prettier's JSON printer:
# - A non-empty object puts each key on its own line.
# - An array goes on one line when it fits in 80 columns, counting the text before
#   it on the line and the comma after it. Otherwise each element goes on its own line.
# - An array of two or more elements that are all objects, or all arrays, each with
#   two or more entries, always breaks.
# - An array of two or more numbers that does not fit packs as many numbers on each
#   line as fit.
# - Two-space indent, and a newline at the end of the file.
module PrettierJson
  WIDTH = 80

  def self.generate(value)
    "#{print(value, 0, 0, 0)}\n"
  end

  # col: the column where the value starts. tail: how many characters follow it on
  # the same line (1 for a comma, else 0).
  def self.print(value, indent, col, tail)
    case value
    when Hash then print_object(value, indent)
    when Array then print_array(value, indent, col, tail)
    else JSON.generate(value)
    end
  end

  def self.print_object(hash, indent)
    return "{}" if hash.empty?

    pad = " " * (indent + 2)
    lines = hash.each_with_index.map do |(key, value), i|
      prefix = "#{pad}#{JSON.generate(key.to_s)}: "
      prefix + print(value, indent + 2, prefix.size, i == hash.size - 1 ? 0 : 1)
    end
    "{\n#{lines.join(",\n")}\n#{' ' * indent}}"
  end

  def self.print_array(array, indent, col, tail)
    return "[]" if array.empty?

    flat = flat(array)
    return flat if flat && !always_break?(array) && col + flat.size + tail <= WIDTH

    pad = " " * (indent + 2)
    body = numbers?(array) ? fill(array, pad) : one_per_line(array, indent, pad)
    "[\n#{body}\n#{' ' * indent}]"
  end

  def self.one_per_line(array, indent, pad)
    array.each_with_index.map do |element, i|
      pad + print(element, indent + 2, pad.size, i == array.size - 1 ? 0 : 1)
    end.join(",\n")
  end

  # The one-line form, or nil when an element cannot go on one line.
  def self.flat(value)
    case value
    when Hash then value.empty? ? "{}" : nil
    when Array
      parts = value.map { |element| flat(element) }
      return nil if parts.any?(&:nil?) || value.any? { |element| element.is_a?(Array) && always_break?(element) }

      "[#{parts.join(', ')}]"
    else JSON.generate(value)
    end
  end

  def self.always_break?(array)
    return false if array.size < 2

    kind = array.first.class
    [ Hash, Array ].include?(kind) && array.all? { |element| element.instance_of?(kind) && element.size > 1 }
  end

  def self.numbers?(array)
    array.size > 1 && array.all?(Numeric)
  end

  # Each element with its comma ("12,") goes on the current line when it fits after
  # a space; otherwise it starts a new line.
  def self.fill(array, pad)
    lines = [ pad.dup ]
    array.each_with_index do |number, i|
      item = JSON.generate(number) + (i == array.size - 1 ? "" : ",")
      if lines.last == pad
        lines.last << item
      elsif lines.last.size + 1 + item.size <= WIDTH
        lines.last << " " << item
      else
        lines << (pad + item)
      end
    end
    lines.join("\n")
  end
end
