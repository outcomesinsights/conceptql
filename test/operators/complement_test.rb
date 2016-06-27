require_relative '../helper'

describe ConceptQL::Operators::Complement do
  it "should produce correct results" do
    cids = criteria_ids(
      [
        :complement,
        [
          :icd9,
          "412"
        ]
      ]
    )["condition_occurrence"]
    cids.count.must_equal 59842

    [
      2151,
      2428,
      3995,
      4545,
      4710,
      5069,
      5263,
      5582,
      8725,
      10403,
      10590,
      11135,
      11228,
      11589,
      11800,
      13234,
      13893,
      14604,
      14702,
      14854,
      14859,
      17103,
      17593,
      23234,
      23411,
      24627,
      25492,
      26245,
      27343,
      37521,
      38787,
      50019,
      50933,
      52644,
      52675,
      53214,
      53216,
      53251,
      53630,
      53733,
      53801,
      55383,
      56352,
      56634,
      56970,
      57089,
      57705,
      58271,
      58448,
      58596,
      58610,
      58623,
      59732,
      59760,
      59785
    ].each do |i|
      cids.wont_include(i)
    end

    criteria_ids(
      [
        :complement,
        [
          :complement,
          [
            :icd9,
            "412"
          ]
        ]
      ]
    ).must_equal(
      {
        "condition_occurrence" => [
          2151,
          2428,
          3995,
          4545,
          4710,
          5069,
          5263,
          5582,
          8725,
          10403,
          10590,
          11135,
          11228,
          11589,
          11800,
          13234,
          13893,
          14604,
          14702,
          14854,
          14859,
          17103,
          17593,
          23234,
          23411,
          24627,
          25492,
          26245,
          27343,
          37521,
          38787,
          50019,
          50933,
          52644,
          52675,
          53214,
          53216,
          53251,
          53630,
          53733,
          53801,
          55383,
          56352,
          56634,
          56970,
          57089,
          57705,
          58271,
          58448,
          58596,
          58610,
          58623,
          59732,
          59760,
          59785
        ]
      }
    )

    criteria_counts(
      [
        :complement,
        [
          :union,
          [
            :icd9,
            "412"
          ],
          [
            :condition_type,
            :inpatient_header
          ]
        ]
      ]
    ).must_equal(
      {
        "condition_occurrence" => 58308
      }
    )

    criteria_counts(
      [
        :intersect,
        [
          :complement,
          [
            :icd9,
            "412"
          ]
        ],
        [
          :complement,
          [
            :condition_type,
            :inpatient_header
          ]
        ]
      ]
    ).must_equal(
      {
        "condition_occurrence" => 58308
      }
    )

    criteria_counts(
      [
        :complement,
        [
          :union,
          [
            :icd9,
            "412"
          ],
          [
            :condition_type,
            :inpatient_header
          ],
          [
            :cpt,
            "99214"
          ]
        ]
      ]
    ).must_equal(
      {
        "condition_occurrence" => 58308,
        "procedure_occurrence" => 37296
      }
    )

    criteria_counts(
      [
        :intersect,
        [
          :complement,
          [
            :icd9,
            "412"
          ]
        ],
        [
          :complement,
          [
            :condition_type,
            :inpatient_header
          ]
        ],
        [
          :complement,
          [
            :cpt,
            "99214"
          ]
        ]
      ]
    ).must_equal(
      {
        "condition_occurrence" => 58308,
        "procedure_occurrence" => 37296
      }
    )

    criteria_counts(
      [
        :union,
        [
          :intersect,
          [
            :complement,
            [
              :icd9,
              "412"
            ]
          ],
          [
            :complement,
            [
              :condition_type,
              :inpatient_header
            ]
          ]
        ],
        [
          :complement,
          [
            :cpt,
            "99214"
          ]
        ]
      ]
    ).must_equal(
      {
        "condition_occurrence" => 58308,
        "procedure_occurrence" => 37296
      }
    )
  end

  it "should handle upstream errors in annotations" do
    query(
      [
        :complement
      ]
    ).annotate.must_equal(
      [
        "complement",
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
      [
        :complement,
        [
          :icd9,
          "412"
        ],
        [
          :icd9,
          "412"
        ]
      ]
    ).annotate.must_equal(
      [
        "complement",
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
              :condition_occurrence => {
                :rows => 0,
                :n => 0
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
      [
        :complement,
        "412",
        [
          :icd9,
          "412"
        ]
      ]
    ).annotate.must_equal(
      [
        "complement",
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
        "412",
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
                "has arguments"
              ]
            ]
          }
        }
      ]
    )
  end
end

