require_relative '../helper'

describe ConceptQL::Operators::First do
  it "should produce correct results" do
    criteria_ids(
      [:first, [:icd9, "412"]]
    ).must_equal("condition_occurrence"=>[1712, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 9882, 10443, 10865, 13016, 13741, 15149, 17041, 17772, 18412, 18555, 19736, 20037, 21006, 21627, 22875, 22933, 24471, 24721, 24989, 25417, 25875, 26766, 27388, 28177, 30831, 31387, 31792, 32104, 32463, 32981])

    criteria_ids(
      [:first, [:cpt, "99214"]]
    ).must_equal("procedure_occurrence"=>[48, 118, 167, 376, 609, 652, 681, 758, 847, 1102, 1401, 1589, 1970, 2576, 2876, 3040, 3277, 3289, 3519, 3676, 3990, 4069, 4196, 4330, 4518, 4896, 4998, 5052, 5076, 5191, 5392, 5517, 5777, 5866, 5894, 5954, 6088, 6192, 6591, 6776, 7064, 7186, 7326, 7542, 7554, 7740, 7951, 8027, 8289, 8489, 8692, 8759, 8830, 8957, 9413, 9572, 9711, 10327, 10643, 10746, 10827, 10890, 11033, 11167, 11202, 11839, 11942, 12102, 12356, 12488, 12523, 12629, 12813, 12954, 13190, 13340, 13462, 13757, 13794, 13957, 14145, 14263, 14292, 14339, 14416, 14437, 15062, 15434, 15459, 15612, 15808, 15950, 16099, 16202, 16398, 16472, 16641, 16732, 16877, 16998, 17172, 17249, 17487, 17783, 17825, 18062, 18090, 18165, 18253, 18292, 18415, 18467, 18667, 18694, 18801, 18895, 19079, 19450, 19700, 19958, 20031, 20208, 20306, 20430, 20658, 20775, 20795, 20946, 21286, 21495, 21578, 21798, 22606, 22741, 22995, 23127, 23269, 23423, 23600, 23808, 23975, 24058, 24252, 24283, 24372, 24437, 24602, 24884, 25105, 25169, 25567, 25746, 26264, 26658, 26841, 27001, 27153, 27501, 27773, 27871, 27969, 28116, 28259, 28584, 28807, 28855, 29016, 29057, 29365, 29899, 30052, 30099, 30324, 30377, 30434, 30528, 31100, 31456, 31583, 31776, 32016, 32213, 32343, 33129, 33194, 33320, 33329, 33544, 33602, 33765, 34058, 34350, 34582, 34655, 34664, 34892, 35053, 35136, 35237, 35481, 35558, 35591, 35618])

    criteria_ids(
      [:first, [:union, [:icd9, "412"], [:death, true]]]
    ).must_equal("death"=>[177], "condition_occurrence"=>[1712, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 9882, 10443, 10865, 13016, 13741, 15149, 17041, 17772, 18412, 18555, 19736, 20037, 21006, 21627, 22875, 22933, 24471, 24721, 24989, 25417, 25875, 26766, 27388, 28177, 30831, 31387, 31792, 32104, 32463, 32981])
  end
end

