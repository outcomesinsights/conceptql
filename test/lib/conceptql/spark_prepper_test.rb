require "pathname"
require "fileutils"
require_relative "../../helper"

describe ConceptQL::SparkPrepper do
  let(:db) { Sequel.connect("mock://spark") }
  let(:parquet_files_dir) do
    Pathname.new(Dir.mktmpdir).tap do |dir|
      FileUtils.touch((dir + "a.parquet").to_s)
      FileUtils.touch((dir + "b.parquet").to_s)
    end
  end

  describe ".prep" do
    describe "with no options" do
      it "should create views" do
        ConceptQL::SparkPrepper.new(db, parquet_files_dir).prep
        sqls = db.sqls.dup
        assert sqls.any? { |sql| sql =~ /CREATE TEMPORARY VIEW `a`/ }
        assert sqls.any? { |sql| sql =~ /CREATE TEMPORARY VIEW `b`/ }
      end
    end

    describe "with schema and table_opts" do
      it "should create views and tables" do
        ConceptQL::SparkPrepper.new(db, parquet_files_dir).prep(schema: :some_schema)
        sqls = db.sqls.dup
        assert sqls.any? { |sql| sql =~ /CREATE TEMPORARY VIEW `a`/ }
        assert sqls.any? { |sql| sql =~ /CREATE TEMPORARY VIEW `b`/ }
        assert sqls.any? { |sql| sql =~ /CREATE TABLE `some_schema`.`a`/ }
        assert sqls.any? { |sql| sql =~ /CREATE TABLE `some_schema`.`b`/ }
      end
    end

    describe "with schema and cache/statistics options" do
      it "should create views and tables" do
        ConceptQL::SparkPrepper.new(db, parquet_files_dir).prep(schema: :some_schema, table_opts: { a: { cache: true }, b: { compute_statistics: true } })
        sqls = db.sqls.dup
        assert sqls.any? { |sql| sql =~ /CREATE TEMPORARY VIEW `a`/ }
        assert sqls.any? { |sql| sql =~ /CREATE TEMPORARY VIEW `b`/ }
        assert sqls.any? { |sql| sql =~ /CREATE TABLE `some_schema`.`a`/ }
        assert sqls.any? { |sql| sql =~ /CACHE LAZY TABLE `some_schema`.`a`/ }
        assert sqls.all? { |sql| sql !~ /ANALYZE TABLE `some_schema`.`a` COMPUTE STATISTICS/ }
        assert sqls.any? { |sql| sql =~ /CREATE TABLE `some_schema`.`b`/ }
        assert sqls.all? { |sql| sql !~ /CACHE LAZY TABLE `some_schema`.`b`/ }
        assert sqls.any? { |sql| sql =~ /ANALYZE TABLE `some_schema`.`b` COMPUTE STATISTICS/ }
      end
    end

    describe "with schema and table_opts list" do
      it "should create views and tables" do
        ConceptQL::SparkPrepper.new(db, parquet_files_dir).prep(schema: :some_schema, table_opts: {
          a: {
            using: :parquet,
            partitioned_by: :c,
            clustered_by: :d,
            sorted_by: :e,
            num_buckets: 4
          }
        })
        sqls = db.sqls.dup
        assert sqls.any? { |sql| sql =~ /CREATE TABLE `some_schema`.`a`/ }
        assert sqls.any? { |sql| sql =~ /USING parquet/ }
        assert sqls.any? { |sql| sql =~ /PARTITIONED BY \(`c`\)/ }
        assert sqls.any? { |sql| sql =~ /CLUSTERED BY \(`d`\)/ }
        assert sqls.any? { |sql| sql =~ /SORTED BY \(`e`\)/ }
        assert sqls.any? { |sql| sql =~ /INTO 4 BUCKETS/ }
      end
    end
  end
end
