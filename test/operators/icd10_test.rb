require_relative '../helper'

describe ConceptQL::Operators::Icd10 do
  it "should produce correct results" do
    criteria_ids(
      [:icd10, 'Z56.1']
    ).must_equal("condition_occurrence"=>[34546])
  end

  it "should handle errors when annotating" do
    query(
      [:icd10, [:icd9, "412"]]
    ).annotate.must_equal(
      [
        "icd10",
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
        {
          :annotation => {
            :counts => {
              :condition_occurrence => {
                :n => 0,
                :rows => 0
              }
            },
            :errors => [
              [
                "has upstreams",
                [
                  "icd9"
                ]
              ],
              [
                "has no arguments"
              ]
            ]
          },
          :name => "ICD-10 CM"
        }
      ]
    )
  end
end
