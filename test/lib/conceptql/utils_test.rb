# frozen_string_literal: true

require_relative "../../helper"

describe ConceptQL::Utils do
  describe ".rekey" do
    it "should symbolize all hash keys" do
      h = {
        "a" => {
          "b" => [ "c", { "d" => "e" } ]
        }
      }
      expected = {
        a: {
          b: [ "c", { d: "e" } ]
        }
      }
      _(ConceptQL::Utils.rekey(h)).must_equal expected
    end

    it "should symbolize all values if option is set" do
      h = {
        "a" => {
          "b" => [ "c", { "d" => "e" } ]
        }
      }
      expected = {
        a: {
          b: [ :c, { d: :e } ]
        }
      }
      _(ConceptQL::Utils.rekey(h, rekey_values: true)).must_equal expected
    end
  end

  describe ".timed_capture" do
    it "should timeout if process takes too long" do
      assert_raises(Timeout::Error) { ConceptQL::Utils.timed_capture("sleep", "10", timeout: 1) }
    end

    it "should not timeout if process is fast enough" do
      value = ConceptQL::Utils.timed_capture("echo", "-n", "hi", timeout: 1)
      assert_equal "hi", value
    end
  end

  describe ".assemble_date" do
    let(:db) { Sequel.mock }
    it "should preface with table if provided" do
      query = db[:tab].select(ConceptQL::Utils.assemble_date(:year, :month, :day, table: :tab).as(:new_col))
      assert_equal(
        "SELECT (coalesce(lpad(CAST(tab.year AS varchar(255)), 2, '0'), '01') || '-' || coalesce(lpad(CAST(tab.month AS varchar(255)), 2, '0'), '01') || '-' || coalesce(lpad(CAST(tab.day AS varchar(255)), 2, '0'), '01')) AS new_col FROM tab",
        query.sql
      )
    end
  end
end
