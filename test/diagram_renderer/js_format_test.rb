# frozen_string_literal: true

require_relative "helper"

# The expected strings are what Node prints for the same values (String(v),
# Array#join, Object.keys, trimEnd), checked on 2026-11-03.
describe ConceptQL::DiagramRenderer::JsFormat do
  let(:js) { ConceptQL::DiagramRenderer::JsFormat }

  it "writes numbers as Number::toString does" do
    numbers = [ 100, 100.0, -0.0, 0.01, -99.99, 1e21, 1e-7, 1.5e-6, 2.5e-5, 123_456_789_012_345_680_000.0,
                0.1 + 0.2, 1e300, 5e-324, 1234.5678, Float::NAN, Float::INFINITY, -Float::INFINITY ]

    _(numbers.map { js.number(_1) }).must_equal(%w[
      100 100 0 0.01 -99.99 1e+21 1e-7 0.0000015 0.000025 123456789012345680000
      0.30000000000000004 1e+300 5e-324 1234.5678 NaN Infinity -Infinity
    ])
  end

  it "writes values as String() does, with null array elements empty" do
    _(js.string([ 1, nil, [ 2, 3.0 ], "a", nil ])).must_equal("1,,2,3,a,")
    _(js.string({})).must_equal("[object Object]")
    _(js.string(nil)).must_equal("null")
    _(js.join([ "a", nil, 1.5 ], ", ")).must_equal("a, , 1.5")
  end

  it "orders object entries as Object.entries does" do
    keys = js.entries({ "b" => 1, "2" => 1, "a" => 1, "1" => 1, "01" => 1, "4294967295" => 1, "4294967294" => 1 }).map(&:first)

    _(keys).must_equal(%w[1 2 4294967294 b a 01 4294967295])
  end

  it "trims JavaScript whitespace only" do
    _(js.trim_end(" a \t ﻿　")).must_equal(" a")
    _(js.trim_end("a\u0085")).must_equal("a\u0085")
  end

  it "treats the JavaScript falsy values as falsy" do
    [ nil, false, 0, 0.0, Float::NAN, "" ].each { |value| _(js.truthy?(value)).must_be_same_as(false) }
    [ "0", [], {}, 1, -1.5 ].each { |value| _(js.truthy?(value)).must_be_same_as(true) }
  end
end
