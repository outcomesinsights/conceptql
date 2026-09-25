# frozen_string_literal: true

require 'tempfile'
require_relative '../../db_helper'
require_relative '../../../lib/conceptql/cli'

describe ConceptQL::Diagram do
  # No claims database: what the render_json CLI uses without --counts.
  let(:nodb) { ConceptQL::Diagram.default_cdb(CDB.opts[:data_model]) }

  def render(statement, cdb: nodb, counts: false)
    ConceptQL::Diagram.render(statement, cdb: cdb, counts: counts)
  end

  # A vocabulary operator's human name depends on the lexicon the suite runs
  # with ("Condition Type" from the bundled vocabularies.csv, "OMOP Condition
  # Occurrence Type" from ohdsi_vocabs), so it is taken from the operator
  # itself. Every other expected value below is a literal.
  def human(*operator)
    nodb.nodifier.create(*operator).send(:preferred_name)
  end

  def icd9(*codes, **extra)
    {
      name: 'icd9',
      base: 'selection',
      humanName: human('icd9', '412'),
      outputTypes: ['condition_occurrence'],
      parameters: {},
      values: codes,
      children: []
    }.merge(extra)
  end

  describe '.render' do
    it 'renders a single selection operator' do
      _(render([%w[icd9 412]])).must_equal(
        format: 'conceptql-diagram/v1',
        statements: [icd9('412')]
      )
    end

    it 'renders a binary filter with its left child before its right child' do
      statement = JSON.parse(<<~JSON)
        [["during", {"left": ["union", ["icd9", "250.00", "250.02"], ["icd9", "401.9"]],
                     "right": ["condition_type", "inpatient"]}]]
      JSON

      _(render(statement)[:statements]).must_equal(
        [
          {
            name: 'during',
            base: 'filter',
            humanName: 'During',
            outputTypes: ['condition_occurrence'],
            parameters: {},
            values: [],
            children: [
              {
                name: 'union',
                base: 'set',
                humanName: 'Union',
                outputTypes: ['condition_occurrence'],
                parameters: {},
                values: [],
                children: [icd9('250.00', '250.02'), icd9('401.9')]
              },
              {
                name: 'condition_type',
                base: 'selection',
                humanName: human('condition_type', 'inpatient'),
                outputTypes: ['condition_occurrence'],
                parameters: {},
                values: ['inpatient'],
                children: []
              },
            ]
          },
        ]
      )
    end

    it 'keeps a label as a parameter and resolves a recall to the labelled types' do
      statement = ['union', ['icd9', '412', { 'label' => 'heart attack', 'id' => 7 }], ['recall', 'heart attack']]

      _(render(statement)[:statements]).must_equal(
        [
          {
            name: 'union',
            base: 'set',
            humanName: 'Union',
            outputTypes: ['condition_occurrence'],
            parameters: {},
            values: [],
            children: [
              icd9('412', parameters: { label: 'heart attack' }),
              {
                name: 'recall',
                base: 'selection',
                humanName: 'Recall',
                outputTypes: ['condition_occurrence'],
                parameters: {},
                values: ['heart attack'],
                children: []
              },
            ]
          },
        ]
      )
    end

    it 'puts errors on the node that has them' do
      statement = ['union', %w[not_a_real_op x], ['recall', 'No Such Label']]

      _(render(statement)[:statements]).must_equal(
        [
          {
            name: 'union',
            base: 'set',
            humanName: 'Union',
            outputTypes: ['invalid'],
            parameters: {},
            values: [],
            children: [
              {
                name: 'not_a_real_op',
                base: nil,
                humanName: 'Invalid',
                outputTypes: ['invalid'],
                parameters: {},
                values: ['x'],
                children: [],
                errors: [['invalid operator', 'not_a_real_op']]
              },
              {
                name: 'recall',
                base: 'selection',
                humanName: 'Recall',
                outputTypes: ['invalid'],
                parameters: {},
                values: ['No Such Label'],
                children: [],
                errors: [['no matching label', 'No Such Label']]
              },
            ]
          },
        ]
      )
    end

    # scope_annotate keys warnings by operator name, so these two nodes would
    # share one entry there; the render tree keeps them apart.
    it 'keeps warnings on the one of two same-named nodes that has them' do
      statement = ['union', %w[icd9 412], ['icd9', '00.00']]

      _(render(statement)[:statements].first[:children]).must_equal(
        [icd9('412'), icd9('00.00', warnings: [['improperly formatted code', '00.00']])]
      )
    end

    it 'renders each statement of a list, in order' do
      _(render([%w[icd9 412], %w[icd9 799.22]])[:statements]).must_equal([icd9('412'), icd9('799.22')])
    end

    it 'omits counts unless asked for them' do
      _(render([%w[icd9 412]])[:statements].first.key?(:counts)).must_equal(false)
    end

    it 'adds per-domain rows and person counts when asked, matching the query it annotates' do
      node = render([%w[icd9 412]], cdb: CDB, counts: true)[:statements].first

      ds = CDB.query(%w[icd9 412]).query.from_self
      rows = ds.count
      n = ds.select(:person_id).distinct.count

      _(rows).must_be :>, 0 # a 0 == 0 match would prove nothing

      _(node[:counts]).must_equal('condition_occurrence' => { rows: rows, n: n })
      _(node[:outputTypes]).must_equal(['condition_occurrence'])
    end
  end

  describe ConceptQL::Diagram::JigsawTree do
    # Cases ported from the Jigsaw diagram editor's ConceptqlAdapter spec.
    def jigsaw(statements)
      ConceptQL::Diagram::JigsawTree.new(statements, cdb: nodb).to_jigsaw_json
    end

    it 'converts a binary operator into left and right children' do
      _(jigsaw('[["except",{"left":["icd9","412"],"right":["condition_type","primary"]}]]')).must_equal(
        { name: 'root', children: [{ name: 'except', children: [{ name: 'icd9', values: ['412'] },
                                                                { name: 'condition_type', values: ['primary'] }] }] }
      )
    end

    it 'drops the missing side of a binary operator' do
      _(jigsaw('[["except",{"left":["icd9","412"]}]]')).must_equal(
        { name: 'root', children: [{ name: 'except', children: [{ name: 'icd9', values: ['412'] }] }] }
      )
    end

    it 'keeps integer values and drops the id parameter' do
      _(jigsaw('[["occurrence",17,["cpt","99214"]],["icd9","412",{"label":"something","id":1}]]')).must_equal(
        { name: 'root', children: [
          { name: 'occurrence', values: [17], children: [{ name: 'cpt', values: ['99214'] }] },
          { name: 'icd9', values: ['412'], parameters: { 'label' => 'something' } },
        ] }
      )
    end

    it 'accepts an unnested statement and an empty list' do
      _(jigsaw('["icd9","412"]')).must_equal({ name: 'root', children: [{ name: 'icd9', values: ['412'] }] })
      _(jigsaw('[]')).must_equal({ name: 'root', children: [] })
    end
  end

  describe 'render_json CLI' do
    def cli_stdout(statement)
      Tempfile.create(['statement', '.json']) do |f|
        f.write(JSON.generate(statement))
        f.flush
        out, = capture_io { ConceptQL::CLI.start(['render_json', f.path]) }
        out
      end
    end

    it 'prints the conceptql-diagram/v1 document' do
      doc = JSON.parse(cli_stdout([%w[icd9 412]]))

      _(doc['format']).must_equal('conceptql-diagram/v1')
      _(doc['statements']).must_equal(
        [{ 'name' => 'icd9', 'base' => 'selection', 'humanName' => human('icd9', '412'),
           'outputTypes' => ['condition_occurrence'], 'parameters' => {}, 'values' => ['412'], 'children' => [] }]
      )
    end

    it 'prints a stable, snapshot-able text' do
      _(cli_stdout(['cpt', '99214', { 'label' => 'visit' }])).must_equal(<<~JSON)
        {
          "format": "conceptql-diagram/v1",
          "statements": [
            {
              "name": "cpt",
              "base": "selection",
              "humanName": "#{human("cpt", "99214")}",
              "outputTypes": [
                "procedure_occurrence"
              ],
              "parameters": {
                "label": "visit"
              },
              "values": [
                "99214"
              ],
              "children": []
            }
          ]
        }
      JSON
    end
  end
end
