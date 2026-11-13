# frozen_string_literal: true

require_relative "../../helper"

# Query#extract_metadata says codeset_only: true when every operator except
# union takes no upstreams (the upstreams facet is "none"). t_shank saves
# the value in its performance statistics. Before bead conceptql-9h85, the
# rule was that every operator except union draws :selection (the key that
# diagram_base replaced had the same values). This test computes the old
# rule from diagram_base and checks
# that the new rule gives the same value for every statement in
# test/statements.
# No database: Database.new(nil) builds the operators of each statement.
describe "codeset_only in Query#extract_metadata" do
  def old_codeset_only(query)
    visitor = ConceptQL::Visitors::MetadataExtractor.new
    query.accept(visitor)
    visitor.operators.reject { |op| op.op_name == "union" }.all? { |op| op.class.diagram_base == :selection }
  end

  %i[gdm gdm_wide].each do |dm|
    it "gives the value of the old rule for every statement in test/statements (#{dm})" do
      cdb = ConceptQL::Database.new(nil, data_model: dm)
      files = Pathname.glob("./test/statements/**/*").reject(&:directory?)
      _(files.size).must_be :>, 300
      values = files.map do |file|
        query = cdb.query(JSON.parse(File.read(file)))
        value = query.extract_metadata[:codeset_only]
        _(value).must_equal old_codeset_only(query), file.to_s
        value
      end
      # Both values occur, so the comparison is not vacuous
      _(values.tally.keys.sort_by(&:to_s)).must_equal [ false, true ]
    end
  end
end
