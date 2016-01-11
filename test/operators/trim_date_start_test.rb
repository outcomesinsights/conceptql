require_relative '../helper'

describe ConceptQL::Operators::TrimDateStart do
  it "should produce correct results" do
    criteria_ids(
      trim_date_start: {
        left: { icd9: '412' },
        right: {
          date_range: {
            start: '2008-03-14',
            end: '2010-12-01'
          }
        }
      }
    ).must_equal("condition_occurrence"=>[21619])

    criteria_ids(
      trim_date_start: {
        left: { icd9: '412' },
        right: {
          date_range: {
            start: '2008-03-14',
            end: '2012-01-21'
          }
        }
      }
    ).must_equal({})

    criteria_ids(
      trim_date_start: {
        left: { icd9: '412' },
        right: {
          date_range: {
            start: '2008-03-14',
            end: '2010-11-22'
          }
        }
      }
    ).must_equal("condition_occurrence"=>[17774, 21619])
  end
end
