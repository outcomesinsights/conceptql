# frozen_string_literal: true

require 'English'
module ConceptQL
  module SqlFormatters
    class Formatter
      def available?
        installed?(program)
      end

      def format(sql)
        ConceptQL::Utils.timed_capture(command, stdin_data: sql, timeout: 10)
      rescue Timeout::Error
        sql
      end

      def installed?(name)
        `which #{name} > /dev/null 2>&1`
        $CHILD_STATUS.success?
      end

      def arguments
        []
      end

      def command
        command = [program]
        command += arguments
        command.compact.join(' ')
      end
    end
  end
end
