module ConceptQL
  class SqlFormatter
    def format(sql)
      if command?(formatter)
        sql, _ = Open3.capture2(formatter, stdin_data: sql)
        return sql
      end
      return sql
    rescue
      return sql
    end

    def command?(name)
      `which #{name}`
      $?.success?
    end

    def formatter
      'pg_format'
    end
  end
end
