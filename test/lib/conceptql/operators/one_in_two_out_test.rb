# frozen_string_literal: true

require_relative '../../../helper'

describe ConceptQL::Operators::OneInTwoOut do
  let(:db) do
    ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide)
  end

  # Spark inlines CTEs, so every reference to the upstream is a separate scan
  # (bead conceptql-7qo, seed conceptql-x9w).
  ['Initial Event', 'Confirming Event'].each do |mode|
    it "reads its upstream once in #{mode} mode" do
      sql = db.query(['one_in_two_out', %w[icd9 412], { outpatient_event_to_return: mode }]).sql
      upstream = sql[/"icd9_\d+_1_\w+"/]

      # One definition and one reference.
      _(sql.scan(upstream).size).must_equal 2
    end
  end

  it 'reads its upstream once with scope windows' do
    sql = db.query(['window', ['one_in_two_out', %w[icd9 412], {}],
                    { window_table: %w[icd9 250.00], adjust_window_start: '-1y' }]).sql
    references = sql.scan(/"icd9_\d+_\d+_\w+"/).tally

    # Each icd9 CTE: one definition and at most one reference.
    _(references.values.max).must_be :<=, 2
  end
end
