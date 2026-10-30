# frozen_string_literal: true

require "digest"

# Names a diagram of doc/spec/ as the 2016 knitter did: SHA256 of the
# statement's Ruby 2.x Array#inspect. That knitter eval'd each statement from
# the .md.cql text, so a JSON key such as "left" became the symbol :left.
# Ruby 3.4 changed Hash#inspect, so this module writes the old form itself.
module OldInspect
  def self.call(obj)
    case obj
    when Array then "[#{obj.map { |o| call(o) }.join(', ')}]"
    when Hash then "{#{obj.map { |k, v| "#{k.to_sym.inspect}=>#{call(v)}" }.join(', ')}}"
    else obj.inspect
    end
  end

  # The statement with symbol hash keys, as the YAML blocks of doc/spec.md show it.
  def self.symbolize(obj)
    case obj
    when Array then obj.map { |o| symbolize(o) }
    when Hash then obj.to_h { |k, v| [ k.to_sym, symbolize(v) ] }
    else obj
    end
  end

  def self.sha(statement)
    Digest::SHA256.hexdigest(call(statement))
  end
end
