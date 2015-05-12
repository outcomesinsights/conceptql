require 'spec_helper'
require 'conceptql/operators/condition_type'

describe ConceptQL::Operators::ConditionType do
  it 'behaves itself' do
    ConceptQL::Operators::ConditionType.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'works for inpatient_detail_primary' do
      correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000183))"
      ConceptQL::Operators::ConditionType.new(:inpatient_detail_primary).query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for inpatient_detail_1' do
      correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000184))"
      ConceptQL::Operators::ConditionType.new(:inpatient_detail_1).query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for inpatient_detail_2' do
      correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000185))"
      ConceptQL::Operators::ConditionType.new(:inpatient_detail_2).query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for inpatient_header_primary' do
      correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000199))"
      ConceptQL::Operators::ConditionType.new(:inpatient_header_primary).query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for inpatient_header_1' do
      correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000200))"
      ConceptQL::Operators::ConditionType.new(:inpatient_header_1).query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for outpatient_detail_1' do
      correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000215))"
      ConceptQL::Operators::ConditionType.new(:outpatient_detail_1).query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for outpatient_header_1' do
      correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000230))"
      ConceptQL::Operators::ConditionType.new(:outpatient_header_1).query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for ehr_problem_list' do
      correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000245))"
      ConceptQL::Operators::ConditionType.new(:ehr_problem_list).query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for condition_era_0_day_window' do
      correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000246))"
      ConceptQL::Operators::ConditionType.new(:condition_era_0_day_window).query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for condition_era_30_day_window' do
      correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000247))"
      ConceptQL::Operators::ConditionType.new(:condition_era_30_day_window).query(Sequel.mock).sql.must_equal correct_query
    end

    describe 'with primary' do
      it 'works for just primary' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000183, 38000199, 38000215, 38000230))"
        ConceptQL::Operators::ConditionType.new(:primary).query(Sequel.mock).sql.must_equal correct_query
      end

      it 'works for inpatient_primary' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000183, 38000199))"
        ConceptQL::Operators::ConditionType.new(:inpatient_primary).query(Sequel.mock).sql.must_equal correct_query
      end

      it 'works for outpatient_primary' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000215, 38000230))"
        ConceptQL::Operators::ConditionType.new(:outpatient_primary).query(Sequel.mock).sql.must_equal correct_query
      end
    end

    describe 'with multiple arguments' do
      it 'works for inpatient_detail_1' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000184, 38000185))"
        ConceptQL::Operators::ConditionType.new(:inpatient_detail_1, :inpatient_detail_2).query(Sequel.mock).sql.must_equal correct_query
      end
    end

    describe 'with arguments as strings' do
      it 'works for inpatient_detail_1' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000184, 38000185))"
        ConceptQL::Operators::ConditionType.new('inpatient_detail_1', 'inpatient_detail_2').query(Sequel.mock).sql.must_equal correct_query
      end
    end

    describe 'as category' do
      it 'works for inpatient_detail' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000183, 38000184, 38000185, 38000186, 38000187, 38000188, 38000189, 38000190, 38000191, 38000192, 38000193, 38000194, 38000195, 38000196, 38000197, 38000198))"
        ConceptQL::Operators::ConditionType.new('inpatient_detail').query(Sequel.mock).sql.must_equal correct_query
      end

      it 'works for inpatient_header' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000199, 38000200, 38000201, 38000202, 38000203, 38000204, 38000205, 38000206, 38000207, 38000208, 38000209, 38000210, 38000211, 38000212, 38000213, 38000214))"
        ConceptQL::Operators::ConditionType.new('inpatient_header').query(Sequel.mock).sql.must_equal correct_query
      end

      it 'works for inpatient' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000183, 38000184, 38000185, 38000186, 38000187, 38000188, 38000189, 38000190, 38000191, 38000192, 38000193, 38000194, 38000195, 38000196, 38000197, 38000198, 38000199, 38000200, 38000201, 38000202, 38000203, 38000204, 38000205, 38000206, 38000207, 38000208, 38000209, 38000210, 38000211, 38000212, 38000213, 38000214))"
        ConceptQL::Operators::ConditionType.new('inpatient').query(Sequel.mock).sql.must_equal correct_query
      end

      it 'works for outpatient_detail' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000215, 38000216, 38000217, 38000218, 38000219, 38000220, 38000221, 38000222, 38000223, 38000224, 38000225, 38000226, 38000227, 38000228, 38000229))"
        ConceptQL::Operators::ConditionType.new('outpatient_detail').query(Sequel.mock).sql.must_equal correct_query
      end

      it 'works for outpatient_header' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000230, 38000231, 38000232, 38000233, 38000234, 38000235, 38000236, 38000237, 38000238, 38000239, 38000240, 38000241, 38000242, 38000243, 38000244))"
        ConceptQL::Operators::ConditionType.new('outpatient_header').query(Sequel.mock).sql.must_equal correct_query
      end

      it 'works for outpatient' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000215, 38000216, 38000217, 38000218, 38000219, 38000220, 38000221, 38000222, 38000223, 38000224, 38000225, 38000226, 38000227, 38000228, 38000229, 38000230, 38000231, 38000232, 38000233, 38000234, 38000235, 38000236, 38000237, 38000238, 38000239, 38000240, 38000241, 38000242, 38000243, 38000244))"
        ConceptQL::Operators::ConditionType.new('outpatient').query(Sequel.mock).sql.must_equal correct_query
      end

      it 'works for condition_era' do
        correct_query = "SELECT * FROM condition_occurrence WHERE (condition_type_concept_id IN (38000246, 38000247))"
        ConceptQL::Operators::ConditionType.new('condition_era').query(Sequel.mock).sql.must_equal correct_query
      end
    end
  end
end


