require 'json'
require 'timeout'
require 'pry-byebug'

module ConceptQL
  module Utils
    class << self
      def rekey(h, opts = {})
        # Thanks to: https://stackoverflow.com/a/10721936
        case h
        when Hash
          Hash[
            h.map do |k, v|
              [k.respond_to?(:to_sym) ? k.to_sym : k, rekey(v, opts)]
            end
          ]
        when Sequel::Dataset
          h
        when Enumerable
          h.map { |v| rekey(v, opts) }
        else
          return h unless opts[:rekey_values]
          return h.to_sym if h.respond_to?(:to_sym)

          h
        end
      end

      def blank?(thing)
        thing.nil? || (thing.respond_to?(:empty?) ? thing.empty? : false)
      end

      def present?(thing)
        !blank?(thing)
      end

      # Cut and paste from Facets
      def snakecase(str)
        str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .tr('-', '_')
           .gsub(/\s/, '_')
           .gsub(/__+/, '_')
           .downcase
      end

      # Copy of rails to_sentence method
      def to_sentence(array, options = {})
        default_connectors = {
          words_connector: ', ',
          two_words_connector: ' and ',
          last_word_connector: ', and '
        }

        options = default_connectors.merge!(options)

        case array.length
        when 0
          ''
        when 1
          "#{array[0]}"
        when 2
          "#{array[0]}#{options[:two_words_connector]}#{array[1]}"
        else
          "#{array[0...-1].join(options[:words_connector])}#{options[:last_word_connector]}#{array[-1]}"
        end
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
              wait_thread[:timed_out] = true
              # please note: we are assuming the command will create ONE process (not handling subprocs / proc groups)
              command = "kill -9 #{wait_thread.pid}"
              system(command)
            rescue(Errno::ESRCH)
              # Do nothing!
            end
          end
        end

        if (es = wait_thread.value.exitstatus) && !es.zero?
          raise stderr.read
        end

        out = stdout.read
        stdout.close

        if wait_thread[:timed_out]
          raise Timeout::Error.new("Command #{commands} failed to complete after #{timeout} seconds")
        end

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
        Sequel.join(strings_with_dashes)
      end

      def schema_dump(db)
        schema = db.tables.sort.map do |t|
          columns = db.schema(t).map do |column_name, column_info|
            info = column_info.slice(:type, :allow_null, :primary_key, :default, :comment)
            info[:null] = info.delete(:allow_null) ? nil : false
            info[:primary_key] = info.delete(:primary_key) ? true : nil
            [column_name, info.compact]
          end.to_h
          [t, { columns: columns }]
        end.to_h
        schema.to_yaml
      end
    end
  end
end
