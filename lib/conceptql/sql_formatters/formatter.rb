module ConceptQL
  module SqlFormatters
    class Formatter
      def available?
        installed?(program)
      end

      def format(sql)
        sql, _ = Open3.capture2(command, stdin_data: sql)
        return sql
      rescue
        return sql
      end

      def installed?(name)
        `which #{name}`
        $?.success?
      end

      def arguments
        []
      end

      def command
        command = [program]
        command += arguments
        command.compact.join(" ")
      end
    end
  end
end
