# frozen_string_literal: true

require "climate_control"
require "tmpdir"
require "fileutils"
require_relative "../../db_helper"
require_relative "../../../lib/conceptql/cli"

describe ConceptQL::CLI do
  let(:cli) { ConceptQL::CLI.new }

  describe "metadata" do
    # The command connects through sequelizer; the suite's own connection
    # stands in for it. Spark CI sets CONCEPTQL_PARQUET_TEST_DIR, and DB has
    # already made those files ready.
    def run_metadata(dir)
      ClimateControl.modify(CONCEPTQL_PARQUET_TEST_DIR: nil) do
        Dir.chdir(dir) { cli.stub(:db, ->(_opts) { DB }) { capture_io { cli.metadata } } }
      end
    end

    it "writes metadata.js and metadata.json from the same database" do
      Dir.mktmpdir do |dir|
        run_metadata(dir)

        js = File.read(File.join(dir, "metadata.js"))
        _(js).must_match(/\A\$metadata = .*;\z/m)
        from_js = JSON.parse(js.delete_prefix("$metadata = ").delete_suffix(";"))
        from_json = JSON.parse(File.read(File.join(dir, "metadata.json")))

        _(from_json).must_equal(from_js)
        _(from_json["operators"].keys).must_include("union")
        _(from_json["categories"].first).must_equal("name" => "Select by Clinical Codes", "priority" => 0)
      end
    end
  end
end
