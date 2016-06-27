require_relative '../helper'

describe ConceptQL::Operators::Count do
  it "should produce correct results" do
    criteria_ids(
      [:count, [:numeric, 1, [:ndc, "12745010902"]]]
    ).must_equal("drug_exposure"=>[1])

    criteria_ids(
      [:count, [:icd9_procedure, "00.13"], [:numeric, 1, [:ndc, "12745010902"]]]
    ).must_equal("drug_exposure"=>[1], "procedure_occurrence"=>[29154])

    criteria_ids(
      [:count, [:numeric, 1]]
    )["person"].inject(:+).must_equal(35929)
  end

  it "should handle errors when annotating" do
    query(
      [:count]
    ).annotate.must_equal(
      [
        "count",
        {
          :annotation => {
            :counts => {
              :invalid => {
                :rows => 0,
                :n => 0
              }
            },
            :errors => [
              [
                "has no upstream"
              ]
            ]
          }
        }
      ]
    )

    query(
      [:count, 1]
    ).annotate.must_equal(
      [
        "count",
        1,
        {
          :annotation => {
            :counts => {
              :invalid => {
                :rows => 0,
                :n => 0
              }
            },
            :errors => [
              [
                "has no upstream"
              ],
              [
                "has arguments",
                [
                  1
                ]
              ]
            ]
          }
        }
      ]
    )

    query(
      [:count, [:icd9, "412"], [:icd9, "401.9"]]
    ).annotate.must_equal(
      [
        "count",
        [
          "icd9",
          "412",
          {
            :annotation => {
              :counts => {
                :condition_occurrence => {
                  :rows => 50,
                  :n => 38
                }
              }
            },
            :name => "ICD-9 CM"
          }
        ],
        [
          "icd9",
          "401.9",
          {
            :annotation => {
              :counts => {
                :condition_occurrence => {
                  :rows => 1125,
                  :n => 213
                }
              }
            },
            :name => "ICD-9 CM"
          }
        ],
        {
          :annotation => {
            :counts => {
              :condition_occurrence => {
                :rows => 0,
                :n => 0
              }
            },
            :errors => [
              [
                "has multiple upstreams",
                [
                  "icd9",
                  "icd9"
                ]
              ]
            ]
          }
        }
      ]
    )
  end
end


