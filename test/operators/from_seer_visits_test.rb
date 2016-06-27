require_relative '../helper'

describe ConceptQL::Operators::FromSeerVisits do
  it "should produce correct results" do
    criteria_ids(
      [:from_seer_visits, [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[1, 2])

    criteria_ids(
      [:from_seer_visits, "Doctor", [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[1])

    criteria_ids(
      [:from_seer_visits, "Nurse", [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[2])

    criteria_ids(
      [:from_seer_visits, "Doctor", "Nurse", [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[1,2])
  end

  it "should handle errors when annotating" do
    query(
      [:from_seer_visits]
    ).annotate.must_equal(
      [
        "from_seer_visits",
        {
          :annotation => {
            :counts => {
              :observation => {
                :n => 0,
                :rows => 0
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
      [:from_seer_visits, [:visit_occurrence, [:icd9, "412"]], [:visit_occurrence, [:icd9, "412"]]]
    ).annotate.must_equal(
      [
        "from_seer_visits",
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
          {
            :annotation => {
              :counts => {
                :visit_occurrence => {
                  :rows => 55,
                  :n => 42
                }
              }
            }
          }
        ],
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
          {
            :annotation => {
              :counts => {
                :visit_occurrence => {
                  :rows => 55,
                  :n => 42
                }
              }
            }
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
                "has multiple upstreams",
                [
                  "visit_occurrence",
                  "visit_occurrence"
                ]
              ]
            ]
          }
        }
      ]
    )
  end
end
