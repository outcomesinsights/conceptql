# frozen_string_literal: true

require_relative '../../db_helper'

# Every ConceptQL::Database carries its own operator registry: vocabulary
# operators built from config/vocabularies.csv and from that Database's own
# lexicon, with the built-in operators merged over them.
describe 'ConceptQL::Database#operators' do
  def entry_id(row)
    ConceptQL::Vocabularies::Entry.new(row.to_hash.compact).id
  end

  it 'lets a built-in operator win over a vocabulary of the same name' do
    _(CDB.operators['gender']).must_equal ConceptQL::Operators::Gender
    _(CDB.operators['race']).must_equal ConceptQL::Operators::Race
    _(CDB.operators['ethnicity']).must_equal ConceptQL::Operators::Ethnicity
  end

  it 'works for a Database with no connection' do
    operators = ConceptQL::Database.new(nil).operators

    _(operators['icd9cm']).must_be :<=, ConceptQL::Operators::Vocabulary
    _(operators['gender']).must_equal ConceptQL::Operators::Gender
  end

  it "includes the test database's lexicon-only vocabularies" do
    data_model = CDB.opts[:data_model]
    lexicon_ids = CDB.lexicon.vocabularies.map { |row| entry_id(row) }
    csv_ids = CSV.foreach(ConceptQL.vocabularies_file_path, headers: true, header_converters: :symbol)
                 .map { |row| entry_id(row) }
    lexicon_only = lexicon_ids - csv_ids - ConceptQL::Operators.static_operators.fetch(data_model).keys

    # Premise: the test database has vocabularies that the CSV does not.
    _(lexicon_only).wont_be_empty

    lexicon_only.each do |id|
      _(CDB.operators[id]).must_be :<=, ConceptQL::Operators::Vocabulary
    end
  end

  it 'returns a frozen Hash' do
    _(CDB.operators).must_be :frozen?
    _(ConceptQL::Database.new(nil).operators).must_be :frozen?
  end

  it 'takes the data model as an argument, defaulting to its own' do
    cdb = ConceptQL::Database.new(nil, data_model: :gdm)

    _(cdb.operators).must_be_same_as cdb.operators(:gdm)
    _(cdb.operators(:omopv4_plus)['information_periods']).must_equal ConceptQL::Operators::InformationPeriods
    _(cdb.operators(:omopv4_plus)).wont_be_same_as cdb.operators(:gdm)
  end

  describe "with a vocabulary only in one Database's lexicon" do
    let(:lexicon_db) do
      Sequel.connect('sqlite:/').tap do |db|
        db.create_table!(:vocabulary) do
          String :vocabulary_id
          String :vocabulary_name
        end
        db.create_table!(:concept_ancestor) { String :column }
        db.create_table!(:concept) do
          Integer :concept_id
          String :concept_code
          String :concept_name
          String :vocabulary_id
        end
        db.create_table!(:concept_relationship) { String :column }
        db[:vocabulary].insert(vocabulary_id: 'EXAMPLE', vocabulary_name: 'Example Vocabulary')
      end
    end

    let(:cdb) do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm,
                                                            lexicon: ConceptQL::Lexicon.new(lexicon_db))
    end

    let(:other_cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }

    it 'has an operator for it, and another Database does not' do
      _(cdb.operators['example']).must_be :<=, ConceptQL::Operators::Vocabulary
      _(other_cdb.operators.key?('example')).must_equal false
    end

    it 'lets a query use it' do
      _(cdb.query(%w[example 12]).sql).must_match(/'EXAMPLE'/)
    end

    it 'lets a diagram use it' do
      node = ConceptQL::Diagram.render([%w[example 12]], cdb: cdb)[:statements].first

      _(node[:vocabularyId]).must_equal 'EXAMPLE'
    end
  end
end
