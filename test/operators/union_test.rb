require_relative '../helper'

describe ConceptQL::Operators::Union do
  it "should produce correct results" do
    criteria_counts(
      [:union, [:icd9, "412"], [:icd9, "401.9"]]
    ).must_equal("condition_occurrence"=>1175)

    criteria_counts(
      [:union, [:icd9, "412"], [:icd10, 'Z56.1']]
    ).must_equal("condition_occurrence"=>51)

    criteria_counts(
      [:union, [:icd9, "412"], [:icd10, 'Z56.1'], [:icd9, "401.9"]]
    ).must_equal("condition_occurrence"=>1176)

    criteria_counts(
      [:union, 
        [:union, [:icd9, "412"], [:icd10, 'Z56.1']],
        [:icd9, "401.9"]]
    ).must_equal("condition_occurrence"=>1176)

    criteria_counts(
      [:union,
       [:union, [:icd9, "412"], [:icd9, "401.9"]],
       [:place_of_service_code, "21"]]
    ).must_equal("condition_occurrence"=>1175, "visit_occurrence"=>170)
  end

  it "optimize should produce correct results" do
    criteria_counts(
      query(
        [:union, [:icd9, "412"], [:icd9, "401.9"]]
      ).optimized
    ).must_equal("condition_occurrence"=>1175)

    criteria_counts(
      query(
        [:union, [:icd9, "412"], [:icd10, 'Z56.1']]
      ).optimized
    ).must_equal("condition_occurrence"=>51)

    criteria_counts(
      query(
        [:union, [:icd9, "412"], [:icd10, 'Z56.1'], [:icd9, "401.9"]]
      ).optimized
    ).must_equal("condition_occurrence"=>1176)

    criteria_counts(
      query(
        [:union, 
          [:union, [:icd9, "412"], [:icd10, 'Z56.1']],
          [:icd9, "401.9"]]
      ).optimized
    ).must_equal("condition_occurrence"=>1176)

    criteria_counts(
      query(
        [:union,
          [:union, [:icd9, "412"], [:icd9, "401.9"]],
          [:union, [:icd9, "412"], [:icd9, "401.9"]]]
      ).optimized
    ).must_equal("condition_occurrence"=>1175)

    criteria_counts(
      query(
        [:union,
         [:union, [:icd9, "412"], [:icd9, "401.9"]],
         [:place_of_service_code, "21"]]
      ).optimized
    ).must_equal("condition_occurrence"=>1175, "visit_occurrence"=>170)
  end

  it "annotate should produce correct results" do
    query(
      [:union, [:icd9, "412"], [:icd9, "401.9"]]
    ).annotate.must_equal(
      ["union",
       ["icd9",
        "412",
        {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}},
         :name=>"ICD-9 CM"}],
       ["icd9",
        "401.9",
        {:annotation=>{:condition_occurrence=>{:rows=>1125, :n=>213}},
         :name=>"ICD-9 CM"}],
       {:annotation=>{:condition_occurrence=>{:rows=>1175, :n=>213}}}]
    )    

    query(
      [:union,
       [:union, [:icd9, "412"], [:icd9, "401.9"]],
       [:place_of_service_code, "21"]]
    ).annotate.must_equal(
      ["union",
       ["union",
        ["icd9",
         "412",
         {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}},
          :name=>"ICD-9 CM"}],
        ["icd9",
         "401.9",
         {:annotation=>{:condition_occurrence=>{:rows=>1125, :n=>213}},
          :name=>"ICD-9 CM"}],
        {:annotation=>{:condition_occurrence=>{:rows=>1175, :n=>213}}}],
       ["place_of_service_code",
        "21",
        {:annotation=>{:visit_occurrence=>{:rows=>170, :n=>92}}}],
       {:annotation=>
         {:condition_occurrence=>{:rows=>1175, :n=>213},
          :visit_occurrence=>{:rows=>170, :n=>92}}}]
    )
  end
end
