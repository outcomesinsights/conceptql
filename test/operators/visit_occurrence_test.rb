require_relative '../helper'

describe ConceptQL::Operators::VisitOccurrence do
  it "should produce correct results" do
    criteria_ids(
      [:visit_occurrence, [:icd9, "412"]]
    ).must_equal(
      {
        "visit_occurrence" => [
          849,
          1789,
          2017,
          2151,
          2428,
          3243,
          3422,
          3705,
          3713,
          3944,
          3995,
          4545,
          4710,
          5069,
          5263,
          5582,
          6393,
          7678,
          8579,
          8725,
          9677,
          10221,
          10344,
          10403,
          10590,
          11135,
          11228,
          11589,
          11800,
          22913,
          24179,
          35411,
          36325,
          51306,
          51336,
          51337,
          51366,
          51380,
          51382,
          51423,
          51440,
          51462,
          51617,
          51655,
          51687,
          51806,
          51843,
          52362,
          52377,
          52508,
          52550,
          52813,
          53228,
          53390,
          53477
        ]
      }
    )

    criteria_counts(
      [:visit_occurrence, [:gender, "Male"]]
    ).must_equal("visit_occurrence"=>26403)

    criteria_counts(
      [:visit_occurrence]
    ).must_equal("visit_occurrence"=>53504)
  end

  it "should handle errors when annotating" do
    query(
      [:visit_occurrence, [:icd9, "412"], [:icd9, "412"]]
    ).annotate.must_equal(
      [
        "visit_occurrence",
        [
          "icd9",
          "412",
          {
            :annotation => {
              :counts => {
                :condition_occurrence => {
                  :rows => 55,
                  :n => 42
                }
              }
            },
            :name => "ICD-9 CM"
          }
        ],
        [
          "icd9",
          "412",
          {
            :annotation => {
              :counts => {
                :condition_occurrence => {
                  :rows => 55,
                  :n => 42
                }
              }
            },
            :name => "ICD-9 CM"
          }
        ],
        {
          :annotation => {
            :counts => {
              :visit_occurrence => {
                :n => 0,
                :rows => 0
              }
            },
            :errors => [
              [
                "has multiple upstreams"
              ]
            ]
          }
        }
      ]
    )

    query(
      [:visit_occurrence, 21, [:icd9, "412"]]
    ).annotate.must_equal(
      [
        "visit_occurrence",
        [
          "icd9",
          "412",
          {
            :annotation => {
              :counts => {
                :condition_occurrence => {
                  :rows => 55,
                  :n => 42
                }
              }
            },
            :name => "ICD-9 CM"
          }
        ],
        21,
        {
          :annotation => {
            :counts => {
              :visit_occurrence => {
                :rows => 0,
                :n => 0
              }
            },
            :errors => [
              [
                "has arguments"
              ]
            ]
          }
        }
      ]
    )
  end
end
