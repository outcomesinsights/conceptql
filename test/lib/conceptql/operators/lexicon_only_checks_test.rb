# frozen_string_literal: true

require_relative "../../../db_helper"

# The unknown-code check and the reused-code check read only the lexicon. So
# they also run for a Database that has a lexicon but whose data database is
# nil or a Sequel mock, as the Jigsaw editor builds it to save an algorithm
# (bead conceptql-0ubo). Each Database here gets its lexicon as lexicon:, so
# LEXICON_URL in the environment changes nothing.
describe "the code checks with a lexicon and no data database" do
  # The test data's own lexicon. Every code below is in both fixtures.
  let(:lexicon) { CDB.lexicon }
  let(:data_model) { CDB.opts[:data_model] }

  let(:data_databases) do
    { "a nil data database" => nil, "a mock data database" => Sequel.mock(host: :postgres) }
  end

  def warnings(cdb, statement, opts = {})
    by_operator(ConceptQL::Annotation.new(cdb.query(statement).annotate(opts)).warnings)
  end

  let(:unknown_icd9) { { "icd9" => [ [ "unknown code(s)", "000.00" ] ] } }

  let(:reused_drg) do
    [ "code(s) with more than one meaning",
      "410: Biliary tract proc except only cholecyst w or w/o c.d.e. w/o CC/MCC | " \
      "Chemotherapy without Acute Leukemia As Secondary Diagnosis" ]
  end

  let(:unknown_information_type) { { "information_periods" => [ [ "unknown code(s)", "PART D" ] ] } }

  describe "with a lexicon" do
    it "warns about an unknown code" do
      data_databases.each do |name, data_db|
        cdb = ConceptQL::Database.new(data_db, data_model: data_model, lexicon: lexicon)

        _(warnings(cdb, %w[icd9 000.00 412])).must_equal unknown_icd9, name
      end
    end

    it "warns about a reused DRG code" do
      data_databases.each do |name, data_db|
        cdb = ConceptQL::Database.new(data_db, data_model: data_model, lexicon: lexicon)

        _(warnings(cdb, %w[drg 410])["drg"]).must_include reused_drg, name
      end
    end

    it "warns about an unknown information type code" do
      data_databases.each do |name, data_db|
        cdb = ConceptQL::Database.new(data_db, data_model: data_model, lexicon: lexicon)

        _(warnings(cdb, [ "information_periods", "PART D", "PARTD" ])).must_equal unknown_information_type, name
      end
    end

    it "gives neither warning with skip_db" do
      data_databases.each do |name, data_db|
        cdb = ConceptQL::Database.new(data_db, data_model: data_model, lexicon: lexicon)

        _(warnings(cdb, %w[icd9 000.00 412], skip_db: true)).must_be_empty name
        _(warnings(cdb, %w[drg 410], skip_db: true)["drg"]).wont_include reused_drg, name
        _(warnings(cdb, [ "information_periods", "PART D" ], skip_db: true)).must_be_empty name
      end
    end
  end

  describe "without a lexicon" do
    it "gives no code warning and raises nothing" do
      data_databases.each do |name, data_db|
        cdb = ConceptQL::Database.new(data_db, data_model: data_model, lexicon: ConceptQL::Lexicon.new(nil))
        _(cdb.lexicon.strategy).must_equal :no_db

        _(warnings(cdb, %w[icd9 000.00 412])).must_be_empty name
        _(warnings(cdb, %w[drg 410])["drg"]).wont_include reused_drg, name
        _(warnings(cdb, [ "information_periods", "PART D" ])).must_be_empty name
      end
    end
  end
end
