# frozen_string_literal: true

require_relative "../../../db_helper"

# sum with group_by_person counts the events of each person (seed
# conceptql-6c3, ruled 2026-10-30). The stream has three codes, so plain sum
# gives some persons several rows: one for each source_value. The review that
# found the defect saw person 14 get 7 and 6 on two rows instead of 13.
describe "sum with group_by_person" do
  let(:events) { [ "icd9", "412", "414.01", "250.00" ] }
  let(:grouped) { [ "sum", [ "numeric", 1, events ], { "group_by_person" => true } ] }

  def rows(statement)
    CDB.query(statement).query.all
  end

  # The expected results, computed in Ruby from the events themselves.
  def expected_by_person
    rows(events).group_by { |r| r[:person_id] }.transform_values do |rs|
      {
        value_as_number: rs.length,
        start_date: rs.map { |r| r[:start_date] }.min,
        end_date: rs.map { |r| r[:end_date] }.max
      }
    end
  end

  it "gives one person result per person, with the number of events and the date span" do
    expected = expected_by_person
    _(expected.values.map { |e| e[:value_as_number] }.max).must_be :>, 1 # some person has several events

    actual = rows(grouped)
    _(actual.map { |r| r[:person_id] }.sort).must_equal expected.keys.sort

    actual.each do |r|
      _(r[:criterion_id]).must_equal 0
      _(r[:criterion_table]).must_equal "patients"
      _(r[:criterion_domain]).must_equal "person"
      _(r[:source_value]).must_be_nil
      _(r.slice(:value_as_number, :start_date, :end_date).transform_values { |v| v.is_a?(Numeric) ? v.to_i : v })
        .must_equal expected.fetch(r[:person_id]), "person #{r[:person_id]}"
    end
  end

  it "gives person 14 the 13 events that plain sum split over two rows" do
    plain = rows([ "sum", [ "numeric", 1, events ] ]).select { |r| r[:person_id] == 14 }
    _(plain.length).must_be :>, 1
    _(plain.sum { |r| r[:value_as_number].to_i }).must_equal 13

    person14 = rows(grouped).select { |r| r[:person_id] == 14 }
    _(person14.map { |r| r[:value_as_number].to_i }).must_equal [ 13 ]
  end

  it "gives one result per person and window in a window table" do
    windowed = [ "window", grouped, { "window_table" => [ "date_range", { "start" => "1900-01-01", "end" => "2100-12-31" } ] } ]
    actual = rows(windowed)
    _(actual.length).must_equal actual.map { |r| [ r[:person_id], r[:window_id] ] }.uniq.length
    _(actual.map { |r| r[:person_id] }.uniq.sort).must_equal expected_by_person.keys.sort
  end
end
