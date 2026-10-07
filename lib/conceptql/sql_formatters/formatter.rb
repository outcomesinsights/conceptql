# frozen_string_literal: true

module ConceptQL
  module SqlFormatters
    # An external SQL formatter, given as a command array that reads SQL on
    # stdin, e.g. Formatter.new(%w[sql-formatter -l postgresql]).
    class Formatter
      attr_reader :command

      def initialize(command)
        @command = command
      end

      def available?
        system('which', command.first, out: File::NULL, err: File::NULL)
      end

      def format(sql)
        ConceptQL::Utils.timed_capture(*command, stdin_data: sql, timeout: 10)
      rescue Timeout::Error
        sql
      end
    end
  end
end
