# frozen_string_literal: true

require "climate_control"
require "tmpdir"
require "fileutils"
require_relative "../../db_helper"
require_relative "../../../lib/conceptql/cli"

describe ConceptQL::CLI do
  let(:cli) { ConceptQL::CLI.new }

  describe "help" do
    it "does not list the removed selection_operators command" do
      out, = capture_io { ConceptQL::CLI.start([ "help" ]) }

      _(out).must_match(/^\s*\S+ metadata\b/)
      _(out).wont_match(/selection_operators/)
      _(ConceptQL::CLI.all_commands.keys).wont_include("selection_operators")
    end
  end

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

  describe "CONCEPTQL_PARQUET_TEST_DIR" do
    # CI's Spark job sets a brace pattern, one directory per schema in search
    # path order: "/tmp/synpuf_test_data/{wide,slim}". sequelizer's make_ready
    # (the make_readyable extension) turns each file into a view, and the
    # first file of a name wins.
    it "passes the parquet files of each directory to make_ready, in search path order" do
      Dir.mktmpdir do |dir|
        %w[wide/observations slim/observations slim/patients].each do |name|
          path = File.join(dir, "#{name}.parquet")
          FileUtils.mkdir_p(File.dirname(path))
          FileUtils.touch(path)
        end
        FileUtils.touch(File.join(dir, "slim", "README.txt"))

        made_ready = []
        data_db = Sequel.mock
        data_db.define_singleton_method(:make_ready) { |opts| made_ready << opts }
        ClimateControl.modify(CONCEPTQL_PARQUET_TEST_DIR: "#{dir}/{wide,slim}") do
          cli.stub(:db, ->(_opts) { data_db }) { cli.send(:cdb, {}) }
        end

        _(made_ready).must_equal(
          [
            {
              search_path: [
                [ Pathname("#{dir}/wide/observations.parquet") ],
                [ Pathname("#{dir}/slim/observations.parquet"), Pathname("#{dir}/slim/patients.parquet") ]
              ]
            }
          ]
        )
      end
    end
  end
end
