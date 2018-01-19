require 'json'
require "timeout"

module ConceptQL
  module Utils
    class << self
      def rekey(h)
        # Thanks to: https://stackoverflow.com/a/10721936
        case h
        when Hash
          Hash[
            h.map do |k, v|
              [ k.respond_to?(:to_sym) ? k.to_sym : k, rekey(v) ]
            end
          ]
        when Enumerable
          h.map { |v| rekey(v) }
        else
          h
        end
      end

      def blank?(thing)
        thing.nil? || thing.empty?
      end

      def present?(thing)
        !blank?(thing)
      end

      # Cut and paste from Facets
      def snakecase(str)
        str.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr('-', '_').
          gsub(/\s/, '_').
          gsub(/__+/, '_').
          downcase
      end

      def timed_capture(*commands)
        # Heavily adapted from:
        # https://gist.github.com/lpar/1032297#gistcomment-1738285
        opts = extract_opts!(commands)
        timeout = opts.fetch(:timeout)

        stdin, stdout, stderr, wait_thread = Open3.popen3(*commands)
        wait_thread[:timed_out] = false
        stdin.puts opts[:stdin_data] if opts[:stdin_data]
        stdin.close


        # Purposefully NOT using Timeout.rb because in general it is a dangerous API!
        # http://blog.headius.com/2008/02/rubys-threadraise-threadkill-timeoutrb.html
        Thread.new do
          sleep timeout
          if wait_thread.alive?
            begin
              # please note: we are assuming the command will create ONE process (not handling subprocs / proc groups)
              command = "kill -9 #{wait_thread.pid}"
              system(command)
              wait_thread[:timed_out] = true
            rescue(Errno::ESRCH)
              # Do nothing!
            end
          end
        end

        wait_thread.value # wait for process to finish, one way or the other
        out = stdout.read
        stdout.close

        raise Timeout::Error if wait_thread[:timed_out]

        out
      end

      def extract_opts!(arr)
        return {} unless arr.last.is_a?(Hash)
        arr.pop
      end

      def assemble_date(*symbols)
        opts = extract_opts!(symbols)
        tab = opts[:table] ? Sequel[opts[:table].to_sym] : Sequel

        strings = symbols.map do |symbol|
          sub = '2000'
          col = Sequel.cast_string(tab[symbol])
          if symbol != :year_of_birth
            sub = '01'
            col = Sequel.function(:lpad, col, 2, '0')
          end
          Sequel.function(:coalesce, col, Sequel.expr(sub))
        end

        strings_with_dashes = strings.zip(['-'] * (symbols.length - 1)).flatten.compact
        concatted_strings = Sequel.join(strings_with_dashes)

        date = concatted_strings
        if opts[:database_type] == :impala
          date = Sequel.cast(Sequel.function(:concat_ws, '-', *strings), DateTime)
        end

        date
      end
    end
  end
end
