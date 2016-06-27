require_relative '../helper'

describe ConceptQL::Operators::From do
  it "should produce correct results" do
    count(
      [:from, 'person']
    ).must_equal(250)

    dataset(
      [:from, 'observation_period']
    ).count.must_equal(156)

    dataset(
      [:from, 'condition_occurrence']
    ).count.must_equal(59897)
  end

  it "should handle query_cols for non-CDM tables" do
    query(
      [:from, "other_table"]
    ).operator.query_cols.must_equal(ConceptQL::Operators::SELECTED_COLUMNS)
  end

  it "should handle errors when annotating" do
    query(
      [:from, [:icd9, "412"]]
    ).annotate.must_equal(
      [
        "from",
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
              :invalid => {
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
          }
        }
      ]
    )

    query(
      [:from, 'person', 'observation_period']
    ).annotate.must_equal(
      [
        "from",
        "person",
        "observation_period",
        {
          :annotation => {
            :counts => {
              :observation_period => {
                :n => 0,
                :rows => 0
              }
            },
            :errors => [
              [
                "has multiple arguments",
                [
                  "person",
                  "observation_period"
                ]
              ]
            ]
          }
        }
      ]
    )
  end
end
