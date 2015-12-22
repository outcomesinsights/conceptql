require 'spec_helper'
require 'conceptql'

describe ConceptQL::Query do
  it 'should support named algorithms' do
    db = Sequel.mock
    db.fetch = proc do |sql|
      case sql
      when 'SELECT statement, label FROM concepts WHERE (concept_id = \'foo\') LIMIT 1'
        {:statement=>'["icd9", "779.22"]', :label=>'foo-label'}
      else
      end
    end

    query = ConceptQL::Query.new(db, [:algorithm, 'foo'])
    expect(query.sql).to eq("SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('779.22')) AND (scm.source_vocabulary_id = 2));")

    query = ConceptQL::Query.new(db, [:union, [:algorithm, 'foo'], [:medcode, '10101']])
    expect(query.sql).to eq("SELECT person_id, criterion_id, criterion_type, start_date, end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(NULL AS varchar(255)) AS source_value FROM (SELECT * FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('779.22')) AND (scm.source_vocabulary_id = 2))) AS t1 UNION ALL SELECT * FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('10101')) AND (scm.source_vocabulary_id = 203))) AS t1) AS t1;")
    expect(query.optimized.sql).to eq("SELECT person_id, criterion_id, criterion_type, start_date, end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(NULL AS varchar(255)) AS source_value FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE (((scm.source_code IN ('779.22')) AND (scm.source_vocabulary_id = 2)) OR ((scm.source_code IN ('10101')) AND (scm.source_vocabulary_id = 203)))) AS t1;")

    query = ConceptQL::Query.new(db, [:algorithm, 'foo'], :algorithm_fetcher=>proc{|alg| [[:icd9, alg], alg]})
    expect(query.sql).to eq("SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('foo')) AND (scm.source_vocabulary_id = 2));")
  end

  describe '#annotate' do
    icd9a_sql = "SELECT criterion_type, count(*) AS rows, count(DISTINCT person_id) AS n FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('412')) AND (scm.source_vocabulary_id = 2))) AS t1 GROUP BY criterion_type"
    cpta_sql = "SELECT criterion_type, count(*) AS rows, count(DISTINCT person_id) AS n FROM (SELECT person_id, procedure_occurrence_id AS criterion_id, CAST('procedure_occurrence' AS varchar(255)) AS criterion_type, CAST(procedure_date AS date) AS start_date, coalesce(CAST(procedure_date AS date), procedure_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(procedure_source_value AS varchar(255)) AS source_value FROM procedure_occurrence AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.procedure_concept_id) WHERE ((c.concept_code IN ('99214')) AND (c.vocabulary_id = 4))) AS t1 GROUP BY criterion_type"
   icd9_sql = "SELECT * FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) LIMIT 1"
   cpt_sql = "SELECT * FROM procedure_occurrence AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.procedure_concept_id) LIMIT 1"

    it 'runs queries for all operators in operator tree and returns counts' do
      union_sql = "SELECT criterion_type, count(*) AS rows, count(DISTINCT person_id) AS n FROM (SELECT person_id, criterion_id, criterion_type, start_date, end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(NULL AS varchar(255)) AS source_value FROM (SELECT * FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('412')) AND (scm.source_vocabulary_id = 2))) AS t1 UNION ALL SELECT * FROM (SELECT person_id, procedure_occurrence_id AS criterion_id, CAST('procedure_occurrence' AS varchar(255)) AS criterion_type, CAST(procedure_date AS date) AS start_date, coalesce(CAST(procedure_date AS date), procedure_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(procedure_source_value AS varchar(255)) AS source_value FROM procedure_occurrence AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.procedure_concept_id) WHERE ((c.concept_code IN ('99214')) AND (c.vocabulary_id = 4))) AS t1) AS t1) AS t1 GROUP BY criterion_type"

      db = Sequel.mock
      db.fetch = proc do |sql|
        case sql
        when icd9a_sql
          {:criterion_type=>"condition_occurrence", :rows=>19228, :n=>15936}
        when cpta_sql
          {:criterion_type=>"procedure_occurrence", :rows=>449428, :n=>81027}
        when union_sql
          [{:criterion_type=>"condition_occurrence", :rows=>19228, :n=>15936},
          {:criterion_type=>"procedure_occurrence", :rows=>449428, :n=>81027}]
        end
      end

      query = ConceptQL::Query.new(db, {:union=>[{:icd9=>"412"}, {:cpt=>"99214"}]})
      res = query.annotate
      sqls = db.sqls
      sqls.delete(icd9_sql)
      sqls.delete(cpt_sql)
      sqls.delete("SELECT * FROM (SELECT * FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('412')) AND (scm.source_vocabulary_id = 2))) AS t1 UNION ALL SELECT * FROM (SELECT person_id, procedure_occurrence_id AS criterion_id, CAST('procedure_occurrence' AS varchar(255)) AS criterion_type, CAST(procedure_date AS date) AS start_date, coalesce(CAST(procedure_date AS date), procedure_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(procedure_source_value AS varchar(255)) AS source_value FROM procedure_occurrence AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.procedure_concept_id) WHERE ((c.concept_code IN ('99214')) AND (c.vocabulary_id = 4))) AS t1) AS t1 LIMIT 1")
      expect(sqls).to eq([
        icd9a_sql,
        cpta_sql,
        union_sql])
      expect(res).to eq(["union",
        ["icd9", "412", {:name=>"ICD-9 CM", :annotation=>{:condition_occurrence=>{:rows=>19228, :n=>15936}}}],
        ["cpt", "99214", {:name=>"CPT", :annotation=>{:procedure_occurrence=>{:rows=>449428, :n=>81027}}}],
        {:annotation=>{:condition_occurrence=>{:rows=>19228, :n=>15936},
                       :procedure_occurrence=>{:rows=>449428, :n=>81027}}}])
    end

    it 'runs queries for binary operators ' do
      after_sql = "SELECT criterion_type, count(*) AS rows, count(DISTINCT person_id) AS n FROM (SELECT person_id, criterion_id, criterion_type, start_date, end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(NULL AS varchar(255)) AS source_value FROM (SELECT l.* FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('412')) AND (scm.source_vocabulary_id = 2))) AS l INNER JOIN (SELECT person_id, min(end_date) AS end_date FROM (SELECT person_id, procedure_occurrence_id AS criterion_id, CAST('procedure_occurrence' AS varchar(255)) AS criterion_type, CAST(procedure_date AS date) AS start_date, coalesce(CAST(procedure_date AS date), procedure_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(procedure_source_value AS varchar(255)) AS source_value FROM procedure_occurrence AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.procedure_concept_id) WHERE ((c.concept_code IN ('99214')) AND (c.vocabulary_id = 4))) AS t1 GROUP BY person_id) AS r ON (l.person_id = r.person_id) WHERE (l.start_date > r.end_date)) AS t1) AS t1 GROUP BY criterion_type"
      db = Sequel.mock
      db.fetch = proc do |sql|
        case sql
        when icd9a_sql
          {:criterion_type=>"condition_occurrence", :rows=>19228, :n=>15936}
        when cpta_sql
          {:criterion_type=>"procedure_occurrence", :rows=>449428, :n=>81027}
        when after_sql
          [{:criterion_type=>"condition_occurrence", :rows=>19228, :n=>15936},
          {:criterion_type=>"procedure_occurrence", :rows=>449428, :n=>81027}]
        end
      end

      query = ConceptQL::Query.new(db, [:after, {:left=>[:icd9, "412"], :right=> [:cpt, "99214"]}])
      res = query.annotate
      sqls = db.sqls
      sqls.delete(icd9_sql)
      sqls.delete(cpt_sql)
      sqls.delete("SELECT * FROM (SELECT l.* FROM (SELECT person_id, condition_occurrence_id AS criterion_id, CAST('condition_occurrence' AS varchar(255)) AS criterion_type, CAST(condition_start_date AS date) AS start_date, coalesce(CAST(condition_end_date AS date), condition_start_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(condition_source_value AS varchar(255)) AS source_value FROM condition_occurrence AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON ((scm.target_concept_id = tab.condition_concept_id) AND (scm.source_code = tab.condition_source_value)) WHERE ((scm.source_code IN ('412')) AND (scm.source_vocabulary_id = 2))) AS l INNER JOIN (SELECT person_id, min(end_date) AS end_date FROM (SELECT person_id, procedure_occurrence_id AS criterion_id, CAST('procedure_occurrence' AS varchar(255)) AS criterion_type, CAST(procedure_date AS date) AS start_date, coalesce(CAST(procedure_date AS date), procedure_date) AS end_date, CAST(NULL AS double precision) AS value_as_number, CAST(NULL AS varchar(255)) AS value_as_string, CAST(NULL AS integer) AS value_as_concept_id, CAST(NULL AS varchar(255)) AS units_source_value, CAST(procedure_source_value AS varchar(255)) AS source_value FROM procedure_occurrence AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.procedure_concept_id) WHERE ((c.concept_code IN ('99214')) AND (c.vocabulary_id = 4))) AS t1 GROUP BY person_id) AS r ON (l.person_id = r.person_id) WHERE (l.start_date > r.end_date)) AS t1 LIMIT 1")
      expect(sqls).to eq([
        icd9a_sql,
        cpta_sql,
        after_sql])
      expect(res).to eq(["after",
        {:left=>["icd9", "412", {:name=>"ICD-9 CM", :annotation=>{:condition_occurrence=>{:rows=>19228, :n=>15936}}}],
         :right=>["cpt", "99214", {:name=>"CPT", :annotation=>{:procedure_occurrence=>{:rows=>449428, :n=>81027}}}]},
        {:annotation=>{:condition_occurrence=>{:rows=>19228, :n=>15936},
                       :procedure_occurrence=>{:rows=>449428, :n=>81027}}}])
    end

    it 'handles no rows returned' do
      query = ConceptQL::Query.new(Sequel.mock, {:union=>[{:icd9=>"412"}, {:cpt=>"99214"}]})
      expect(query.annotate).to eq(["union",
        ["icd9", "412", {:name=>"ICD-9 CM", :annotation=>{:condition_occurrence=>{:rows=>0, :n=>0}}}],
        ["cpt", "99214", {:name=>"CPT", :annotation=>{:procedure_occurrence=>{:rows=>0, :n=>0}}}],
        {:annotation=>{:condition_occurrence=>{:rows=>0, :n=>0},
                       :procedure_occurrence=>{:rows=>0, :n=>0}}}])
    end
  end
end
