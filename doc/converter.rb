require_relative '../lib/conceptql'
require 'pp'
require 'json'

$converter = ConceptQL::Converter.new
def my_pp(obj)
  #PP.pp(obj, ''.dup, 10)
  JSON.pretty_generate(obj)
end

def convert(cql)
  header = []
  header << cql.shift while cql.first =~ /^[`#]/
  footer = [cql.pop]
  if cql.first =~ /^\[/
    cql = my_pp(eval(cql.join))
  else
    cql = my_pp($converter.convert(eval(cql.join)))
  end
  [header, cql, "\n", footer].flatten
end

lines = File.readlines('doc/spec.md')
chunks = lines.slice_before { |l| l =~ /```ConceptQL/ }.to_a
outputs = []
outputs << chunks.shift unless chunks.first =~ /```ConceptQL/
puts chunks.count
outputs += chunks.map do |chunk|
  cql, *remainder = chunk.slice_after { |l| l =~ /^```\n$/ }.to_a
  cql = convert(cql)
  [cql, remainder].flatten#.tap { |arr| pp arr; gets }
end.flatten
File.write('/tmp/test.md', outputs.join)
