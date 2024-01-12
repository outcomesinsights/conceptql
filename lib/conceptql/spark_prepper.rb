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
      unless @files_dir.exist?
        raise "Could not find #{files_dir} for Parquet files"
      end
    end

    def prep(opts = {})
      check_opts(opts)
      files_dir.glob("*.parquet").each do |parquet_file|
        make_view(parquet_file, opts)
      end
    end

    def make_view(parquet_file, opts)
      table_name = parquet_file.basename(".*").to_s.to_sym
      db.create_view(table_name, temp: true, using: 'org.apache.spark.sql.parquet', options: { path: parquet_file.expand_path })
      if opts[:schema]
        if (table_opts = opts.dig(:table_opts, table_name)) || opts[:table_opts].nil?
          table_opts = { as: db[table_name] }.merge(table_opts || {})
          db.create_table!(Sequel[opts[:schema].to_sym][table_name], table_opts)
          if table_opts[:compute_statistics]
            db.run("ANALYZE TABLE `#{opts[:schema]}`.`#{table_name}` COMPUTE STATISTICS FOR ALL COLUMNS")
          end
          if table_opts[:cache]
            db.run("CACHE TABLE `#{opts[:schema]}`.`#{table_name}` OPTIONS ( 'storageLevel' = 'MEMORY_ONLY' )")
          end
          db.drop_view(table_name, if_exists: true)
        end
      end
    end

    def check_opts(opts)
      raise "Must specify :schema if caching tables" if opts[:cache] && !opts[:schema]
    end
  end
end