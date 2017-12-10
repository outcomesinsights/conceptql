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
        opts = commands.pop if commands.last.is_a?(Hash)
        opts ||= {}
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
    end
  end
end
