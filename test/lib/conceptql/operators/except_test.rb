require_relative "../../../helper"

describe ConceptQL::Operators::Except do
  describe "under impala using omopv4_plus" do
    let(:db) do
      ConceptQL::Database.new(Sequel.mock(host: :impala), data_model: :omopv4_plus)
    end

    let(:except_statement) do
      [:except, {
        left: ["icd9", "412"],
        right: ["cpt", "99214"]
      }]
    end

    describe "with windows applied" do
      it "should include window_id" do
        db.query([:window, except_statement, window_table: [:date_range, start: '2001-01-01', end: '2001-12-31']]).sql.must_match(/`t1`.`window_id` = `t2`.`window_id`/)
      end
    end

    describe "without windows applied" do
      it "should not include window_id" do
        db.query(except_statement).sql.wont_match(/`t1`.`window_id` = `t2`.`window_id`/)
      end
    end
  end
end


