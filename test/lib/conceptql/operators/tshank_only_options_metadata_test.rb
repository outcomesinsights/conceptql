# frozen_string_literal: true

require_relative "../../../helper"

# Ryan ruled on 2026-10-26 that an option only t_shank gives must not be in
# ConceptQL.metadata, because the diagram editor builds its operator forms
# from the metadata and would offer the option. match reads only_columns,
# except_columns, join_columns and invert_match, and the temporal operators
# read join_columns, but none of them declares these options. Do not add
# `option` declarations for them (bead conceptql-0g0 removed the ones that
# conceptql-zq2 and conceptql-1t8 added). How conceptql reads them is tested
# in match_test.rb and column_names_option_test.rb.
# No live database: the mock never answers a query.
describe "t_shank-only options in ConceptQL.metadata" do
  let(:tshank_only) { %i[only_columns except_columns join_columns invert_match] }
  let(:readers) { %w[after any_overlap before contains during equal match trim_date_end trim_date_start] }

  %i[gdm gdm_wide].each do |dm|
    describe dm.to_s do
      let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: dm) }
      let(:operators_metadata) { ConceptQL.metadata(cdb)[:operators] }

      it "lists every operator that reads them" do
        _(readers - operators_metadata.keys).must_be_empty
      end

      it "is declared on no operator" do
        declaring = operators_metadata.to_h do |name, m|
          [ name, m[:options].keys & tshank_only ]
        end.reject { |_name, keys| keys.empty? }

        _(declaring).must_equal({})
      end
    end
  end
end
