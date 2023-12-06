require "pathname"
require "active_support"

module ConceptQL
  class SparkPrepper
    attr_reader :db, :files_dir

    def initialize(db, files_dir)
      if files_dir.blank?
        raise "Must define CONCEPTQL_PARQUET_TEST_DIR when testing Spark-based adapter"
      end

      @db = db
      @files_dir = Pathname.new(files_dir)
    end

    def prep(schema_name = nil)
      known_views = schema_name.present? ? db.views(schema: schema_name) : db.views
      files_dir.glob("*.parquet").each do |parquet_file|
        table_name = parquet_file.basename(".*").to_s.to_sym
        if schema_name.present?
          table_name = Sequel[schema_name.to_sym][table_name]
        end
        unless known_views.include?(table_name)
          db.create_view(table_name, temp: true, using: 'org.apache.spark.sql.parquet', options: { path: parquet_file.expand_path })
        end
      end
    end
  end
end