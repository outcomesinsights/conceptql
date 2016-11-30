require 'facets/hash/revalue'
require 'facets/hash/symbolize_keys'

module ConceptQL
  class Database
    attr :db, :opts

    def initialize(db, opts={})
      @db = db
      db_type = :impala
      if db
        extensions.each do |extension|
          db.extension extension
        end
        db_type = db.database_type.to_sym
      end

      @opts = opts.revalue { |v| v ? v.to_sym : v }.symbolize_keys
      @opts[:data_model] ||= :omopv4
      @opts[:database_type] ||= db_type
      db.set(db_opts) if db.respond_to?(:set)
    end

    def query(statement, opts={})
      Query.new(db, statement, @opts.merge(opts))
    end

    def db_opts
      opt_regexp = /^#{opts[:database_type]}_db_opt_/i

      env_hash = ENV.to_hash.rekey { |k| k.to_s.downcase }
      opts_hash = opts.rekey { |k| k.to_s.downcase }
      all_opts = env_hash.merge(opts_hash)

      matching_opts = all_opts.select { |k, _| k.match(opt_regexp) }

      matching_opts.each_with_object({}) do |(k,v), h|
        new_key = k.sub(opt_regexp, '')
        h[new_key] = v
      end
    end

    def extensions
      [:date_arithmetic, :error_sql]
    end
  end
end
