require "pathname"

class SparkPrepper
  attr_reader :db, :files_dir

  def initialize(db, files_dir)
    if files_dir.blank?
      raise "Must define CONCEPTQL_PARQUET_TEST_DIR when testing Spark-based adapter"
    end

    @db = db
    @files_dir = Pathname.new(files_dir)
  end

  def prep
    files_dir.glob("*.parquet").each do |parquet_file|
      table_name = parquet_file.basename(".*").to_s.to_sym
      db.create_view(table_name, temp: true, using: 'org.apache.spark.sql.parquet', options: { path: parquet_file.expand_path })
    end
  end
end