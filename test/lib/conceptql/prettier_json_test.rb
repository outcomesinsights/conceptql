# frozen_string_literal: true

require_relative "../../helper"
require_relative "../../prettier_json"

describe PrettierJson do
  # The suite writes results files with PrettierJson, and `just fmt` formats them
  # with prettier. If the two ever disagree, a new results file fails fmt-check.
  it "reproduces every tracked results file byte for byte" do
    files = Dir[File.expand_path("../../results/**/*.json", __dir__)]
    _(files.size).must_be :>, 100

    mismatched = files.reject do |file|
      text = File.read(file)
      PrettierJson.generate(JSON.parse(text)) == text
    end
    _(mismatched).must_be_empty
  end

  it "puts an array on one line only when it fits in 80 columns" do
    short = { "codes" => %w[a b] }
    _(PrettierJson.generate(short)).must_equal "{\n  \"codes\": [\"a\", \"b\"]\n}\n"

    long = { "codes" => Array.new(12) { |i| "code#{i}" } }
    _(PrettierJson.generate(long).lines.size).must_equal 16
  end

  it "always breaks an array of multi-entry arrays" do
    _(PrettierJson.generate([ [ 1, 2 ], [ 3, 4 ] ])).must_equal "[\n  [1, 2],\n  [3, 4]\n]\n"
  end

  it "packs a long array of numbers onto as few lines as fit" do
    text = PrettierJson.generate(Array.new(40) { |i| i * 1000 })
    _(text.lines.map(&:size).max).must_be :<=, 81
    _(text.lines.size).must_be :<, 40
  end
end
