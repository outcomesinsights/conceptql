require 'spec_helper'
require 'conceptql'

describe ConceptQL::Query do
  describe '#query' do
    it 'passes request on to tree' do
      yaml = Psych.dump({ icd9: '799.22' })
      mock_tree = double("tree")
      mock_operator = double("operator")
      mock_query = double("query")
      mock_db = double("db")

      expect(mock_db).to receive(:extend_datasets).with(Module).and_return(mock_db)

      query = ConceptQL::Query.new(mock_db, yaml, mock_tree)
      expect(mock_tree).to receive(:root).with(query).and_return(mock_operator)
      expect(mock_operator).to receive(:evaluate).with(mock_db).and_return(mock_query)
      expect(mock_query).to receive(:tap).and_return(mock_query)
      query.query
    end
  end

  describe '#annotate' do
    it 'runs queries for all operators in operator tree and returns counts' do
      icd9_sql = "SELECT criterion_type, count(*) AS rows, count(DISTINCT person_id) AS n FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('412')) AND (scm.source_vocabulary_id = 2))) AS t1 GROUP BY criterion_type"
      cpt_sql = "SELECT criterion_type, count(*) AS rows, count(DISTINCT person_id) AS n FROM (SELECT person_id, procedure_occurrence_id AS criterion_id, CAST('procedure_occurrence' AS varchar(255)) AS criterion_type, CAST(procedure_date AS date) AS start_date, coalesce(CAST(procedure_date AS date), procedure_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(procedure_source_value AS varchar(255)) AS source_value FROM procedure_occurrence AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.procedure_concept_id) WHERE ((c.concept_code IN ('99214')) AND (c.vocabulary_id = 4))) AS t1 GROUP BY criterion_type"
      union_sql = "SELECT * FROM (SELECT * FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('412')) AND (scm.source_vocabulary_id = 2))) AS t1 UNION ALL SELECT * FROM (SELECT person_id, procedure_occurrence_id AS criterion_id, CAST('procedure_occurrence' AS varchar(255)) AS criterion_type, CAST(procedure_date AS date) AS start_date, coalesce(CAST(procedure_date AS date), procedure_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(procedure_source_value AS varchar(255)) AS source_value FROM procedure_occurrence AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.procedure_concept_id) WHERE ((c.concept_code IN ('99214')) AND (c.vocabulary_id = 4))) AS t1) AS t1 LIMIT 1"
      union_annotate_sql = "SELECT criterion_type, count(*) AS rows, count(DISTINCT person_id) AS n FROM (SELECT person_id, criterion_id, criterion_type, start_date, end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(NULL AS varchar(255)) AS source_value FROM (SELECT * FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('412')) AND (scm.source_vocabulary_id = 2))) AS t1 UNION ALL SELECT * FROM (SELECT person_id, procedure_occurrence_id AS criterion_id, CAST('procedure_occurrence' AS varchar(255)) AS criterion_type, CAST(procedure_date AS date) AS start_date, coalesce(CAST(procedure_date AS date), procedure_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(procedure_source_value AS varchar(255)) AS source_value FROM procedure_occurrence AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.procedure_concept_id) WHERE ((c.concept_code IN ('99214')) AND (c.vocabulary_id = 4))) AS t1) AS t1) AS t1 GROUP BY criterion_type"

      db = Sequel.mock
      db.fetch = proc do |sql|
        case sql
        when icd9_sql
          {:criterion_type=>"condition_occurrence", :rows=>19228, :n=>15936}
        when cpt_sql
          {:criterion_type=>"procedure_occurrence", :rows=>449428, :n=>81027}
        when union_annotate_sql
          [{:criterion_type=>"condition_occurrence", :rows=>19228, :n=>15936},
          {:criterion_type=>"procedure_occurrence", :rows=>449428, :n=>81027}]
        end
      end

      query = ConceptQL::Query.new(db, {:union=>[{:icd9=>"412"}, {:cpt=>"99214"}]})
      res = query.annotate
      sqls = db.sqls
      sqls.delete("SELECT * FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) LIMIT 1")
      sqls.delete("SELECT * FROM procedure_occurrence AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.procedure_concept_id) LIMIT 1")
      expect(sqls).to eq([
        icd9_sql,
        cpt_sql,
        union_sql,
        union_sql,
        union_sql,
        union_sql,
        union_sql,
        union_sql,
        union_annotate_sql])
      expect(res).to eq(["union",
        ["icd9", "412", {:name=>"ICD-9 CM", :annotation=>{:condition_occurrence=>{:rows=>19228, :n=>15936}}}],
        ["cpt", "99214", {:name=>"CPT", :annotation=>{:procedure_occurrence=>{:rows=>449428, :n=>81027}}}],
        {:annotation=>{:condition_occurrence=>{:rows=>19228, :n=>15936},
                       :procedure_occurrence=>{:rows=>449428, :n=>81027}}}])
    end
  end
end
