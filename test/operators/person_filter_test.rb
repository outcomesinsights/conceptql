require_relative '../helper'

describe ConceptQL::Operators::PersonFilter do
  it "should produce correct results" do
    criteria_ids(
      [:person_filter,
       {:left=>[:icd9, "412"], :right=>[:union, [:cpt, "99214"], [:gender, "Male"]]}]
    ).must_equal("condition_occurrence"=>[2151, 2428, 3995, 4545, 4710, 5069, 5263, 5582, 8725, 10403, 10590, 11135, 11228, 11589, 11800, 13234, 13893, 14604, 14702, 14854, 14859, 17103, 17593, 23234, 23411, 24627, 25492, 26245, 27343, 37521, 38787, 50019, 50933, 52644, 52675, 53214, 53216, 53251, 53630, 53733, 53801, 55383, 56352, 56634, 56970, 57089, 57705, 58271, 58448, 58596, 58610, 58623, 59732, 59760, 59785])

    criteria_counts(
      [:person_filter,
       {:left=>[:union, [:icd9, "412"], [:cpt, "99214"]], :right=>[:gender, "Male"]}]
    ).must_equal("condition_occurrence"=>32, "procedure_occurrence"=>611)

    criteria_ids(
      [:person_filter, {:left=>[:gender, "Male"], :right=>[:death, true]}]
    ).must_equal("person"=>[177])

    criteria_ids(
      [:person_filter, {:left=>[:icd9, "412"], :right=>[:gender, "Male"]}]
    ).must_equal("condition_occurrence"=>[3995, 5069, 8725, 10403, 10590, 11228, 11589, 11800, 13893, 14702, 14854, 23411, 24627, 25492, 26245, 27343, 38787, 50019, 50933, 52644, 52675, 53214, 53216, 53630, 55383, 56970, 57705, 58596, 58610, 58623, 59732, 59785])

    criteria_ids(
      [:person_filter, {:left=>[:icd9, "412"], :right=>[:cpt, "99214"]}]
    ).must_equal("condition_occurrence"=>[2151, 2428, 3995, 4545, 4710, 5263, 5582, 8725, 10403, 10590, 11135, 11228, 11589, 11800, 13234, 13893, 14604, 14702, 14854, 14859, 17103, 17593, 23234, 23411, 24627, 25492, 26245, 27343, 37521, 38787, 50019, 50933, 52644, 52675, 53214, 53216, 53251, 53630, 53733, 53801, 55383, 56352, 56634, 56970, 57089, 57705, 58271, 58448, 58596, 58623, 59732, 59760, 59785])
  end
end
