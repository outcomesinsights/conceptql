require_relative "../../helper"

describe ConceptQL::Utils do
  describe ".rekey" do
    it "should symbolize all hash keys" do
      h = {
        "a" => {
          "b" => [ "c", "d" => "e" ]
        }
      }
      expected = {
        :a => {
          :b => [ "c", :d => "e" ]
        }
      }
      ConceptQL::Utils.rekey(h).must_equal expected
    end
  end

  describe ".blank?" do
    it "should find nil/empty things blank" do
      assert ConceptQL::Utils.blank?(nil)
      assert ConceptQL::Utils.blank?([])
      assert ConceptQL::Utils.blank?({})
      assert ConceptQL::Utils.blank?("")
    end

    it "should find non-empty things not-blank" do
      assert !ConceptQL::Utils.blank?([1])
      assert !ConceptQL::Utils.blank?({a: 1})
      assert !ConceptQL::Utils.blank?("1")
    end
  end

  describe ".present?" do
    it "should not find nil/empty things present" do
      assert !ConceptQL::Utils.present?(nil)
      assert !ConceptQL::Utils.present?([])
      assert !ConceptQL::Utils.present?({})
      assert !ConceptQL::Utils.present?("")
    end

    it "should find non-empty things present" do
      assert ConceptQL::Utils.present?([1])
      assert ConceptQL::Utils.present?({a: 1})
      assert ConceptQL::Utils.present?("1")
    end
  end
end

