require_relative '../helper'

describe ConceptQL::Operators::Gender do
  it "should produce correct results" do
    criteria_ids(
      [:gender, 'male']
    ).must_equal(
      {
        "person" => [
          1,
          2,
          4,
          5,
          6,
          7,
          8,
          12,
          14,
          20,
          21,
          23,
          25,
          27,
          28,
          38,
          40,
          45,
          51,
          53,
          55,
          59,
          60,
          63,
          65,
          66,
          68,
          69,
          70,
          73,
          78,
          80,
          82,
          85,
          90,
          91,
          92,
          94,
          95,
          96,
          99,
          101,
          106,
          107,
          108,
          109,
          110,
          112,
          113,
          115,
          117,
          119,
          120,
          125,
          127,
          128,
          129,
          130,
          131,
          132,
          138,
          142,
          143,
          145,
          146,
          148,
          149,
          150,
          152,
          153,
          154,
          158,
          161,
          163,
          164,
          172,
          174,
          175,
          177,
          178,
          181,
          182,
          183,
          187,
          189,
          191,
          192,
          195,
          198,
          203,
          205,
          206,
          207,
          212,
          215,
          218,
          222,
          227,
          229,
          230,
          231,
          233,
          238,
          239,
          244,
          245,
          246,
          249,
          251,
          260,
          262,
          265,
          266,
          268,
          270,
          271,
          273,
          274,
          275,
          276,
          279,
          280,
          285,
          287,
          288,
          289
        ]
      }
    )
  end

  it "should handle errors when annotating" do
    query(
      [:gender, [:icd9, "412"]]
    ).annotate.must_equal(
      [
        "gender",
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
              :person => {
                :rows => 0,
                :n => 0
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
  end
end

