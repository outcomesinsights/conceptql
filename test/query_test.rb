require_relative 'helper'

describe ConceptQL::Query do
  it "should handle errors in the root operator" do
    query(
      :foo
    ).annotate.must_equal(
      ["invalid", {:annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}, :errors=>[["invalid root operator", ":foo"]]}}]
    )
  end

  it "should handle query_cols for non-CDM tables" do
    query(
      [:from, "other_table"]
    ).query_cols.must_equal(ConceptQL::Scope::DEFAULT_COLUMNS.keys)
  end

  it "should raise error if attempting to execute invalid recall" do
    proc do
      criteria_ids(
      ["after",
        {:left=>["during",
                 {:left=>["occurrence", 4, ["icd9", "203.0x", {"label"=>"Meyloma Dx"}]],
                  :right=>["time_window", ["first", ["recall", "Meyloma Dx"]], {"start"=>"0", "end"=>"90d"}]}],
         :right=>["union",
                  ["during",
                   {:left=>["time_window", ["recall", "Qualifying Meyloma Dx"], {"start"=>"-90d", "end"=>"0", "label"=>"Meyloma 90-day Lookback"}],
                    :right=>["cpt", "38220", "38221", "85102", "85095", "3155F", "85097", "88237", "88271", "88275", "88291", "88305", {"label"=>"Bone Marrow"}]}],
                  ["occurrence", 2, ["during",
                                     {:left=>["cpt", "84156", "84166", "86335", "84155", "84165", "86334", "83883", "81264", "82784", "82785", "82787", "82040", "82232", "77074", "77075", "83615", {"label"=>"Other Tests"}],
                                      :right=>["recall", "Meyloma 90-day Lookback"]}]]]}]
      )
    end.must_raise
  end
end

