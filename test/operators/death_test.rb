require_relative '../helper'

describe ConceptQL::Operators::Death do
  it "should produce correct results" do
    criteria_ids(
      [:death]
    ).must_equal("death"=>[177])

    criteria_ids(
      [:death, [:person, true]]
    ).must_equal("death"=>[177])
  end

  it "should handle errors when annotating" do
    query(
      [:death, [:person], [:icd9, "412"]]
    ).annotate.must_equal(
      [
        "death",
        [
          "person",
          {
            :annotation => {
              :counts => {
                :person => {
                  :rows => 250,
                  :n => 250
                }
              }
            }
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
              :death => {
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
      [:death, "412"]
    ).annotate.must_equal(
      [
        "death",
        "412",
        {
          :annotation => {
            :counts => {
              :death => {
                :n => 0,
                :rows => 0
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
