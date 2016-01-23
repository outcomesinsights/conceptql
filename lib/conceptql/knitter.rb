require 'digest'
require 'yaml'
require_relative 'annotate_grapher'
require_relative 'fake_annotater'

module ConceptQL
  class Knitter
    attr :file, :db
    CONCEPTQL_CHUNK_START = /```ConceptQL/
    RESULT_KEYS = %i(person_id criterion_id criterion_type start_date end_date source_value)

    def initialize(db, file)
      @file = Pathname.new(file)
      raise "File must end in .md.cql!" unless file =~ /\.md\.cql$/
      @db = db
    end

    def knit
      lines = file.readlines
      chunks = lines.slice_before { |l| l =~ CONCEPTQL_CHUNK_START }.to_a
      outputs = []
      outputs << chunks.shift unless chunks.first =~ CONCEPTQL_CHUNK_START
      puts chunks.count
      outputs += chunks.map do |chunk|
        cql, *remainder = chunk.slice_after { |l| l =~ /^```\n$/ }.to_a
        cql = ConceptQLChunk.new(cql, cache, self)
        [cql.output, remainder].flatten
      end.flatten
      File.write(file.to_s.sub(/.cql$/, ''), outputs.join)
    end

    def diagram_dir
      @diagram_dir ||= (file.dirname + file.basename('.md.cql')).tap { |d| d.rmtree if d.exist? ; d.mkpath }
    end

    def diagram_relative_path
      @diagram_relative_path ||= diagram_dir.basename
    end

    def diagram_path(stmt, &block)
      png_contents = cache.fetch_or_create(stmt.inspect, &block)
      file_name = (cache.hash_it(stmt) + ".png")
      new_path = (diagram_dir + file_name)
      new_path.write(png_contents)
      diagram_relative_path + file_name
    end

    private
    class ConceptQLChunk
      attr :lines, :cache, :knitter
      def initialize(lines, cache, knitter)
        @cache = cache
        @lines = lines.to_a
        @knitter = knitter
      end

      def output
        diagram_markup
        cache.fetch_or_create(lines.join) do
          create_output
        end
      end

      def titleize(title)
        return '' unless title
        title.map(&:strip).join(" ").gsub('#', '')
      end

      def make_statement_and_title
        lines.shift
        lines.pop
        title, statement = lines.slice_before { |l| l =~ /^\s*#/ }.to_a
        if statement.nil?
          statement = title
          title = nil
        end
        @statement = eval(statement.join)
        @title = titleize(title)
      end

      def statement
        @statement || make_statement_and_title
        @statement
      end

      def title
        @title || make_statement_and_title
        @title
      end

      def create_output
        output = []
        output << title unless title.empty?
        output << ''
        output << "```YAML"
        output << statement.to_yaml
        output << "```"
        output << ''
        output << diagram_markup
        output << ''
        output << table
        output << ''
        output.compact.join("\n")
      end

      def diagram_markup
        diagram_path = diagram(statement)
        return "![#{title}](#{diagram_path})" if diagram_path
        nil
      end

      def table
        results = query(statement).query.limit(10).all rescue nil
        if results
          if results.empty?
            "```No Results found.```"
          else
            resultify(results)
          end
        else
          "```No Results.  Statement is experimental.```"
        end
      end

      def resultify(results)
        rows = []
        rows << rowify(RESULT_KEYS)
        rows << rowify(RESULT_KEYS.map { |c| c.to_s.gsub(/./, '-')})
        results.each do |result|
          rows << rowify(result.values_at(*RESULT_KEYS))
        end
        rows.join("\n")
      end

      def rowify(columns)
        "| #{columns.join(" | ")} |"
      end

      def diagram(stmt)
        knitter.diagram_path(stmt) do |path_name|
          annotated = nil
          begin
            annotated = query(stmt).annotate
          rescue
            #puts $!.message
            #puts $!.backtrace.join("\n")
            annotated = FakeAnnotater.new(stmt).annotate
          end
          ConceptQL::AnnotateGrapher.new.graph_it(annotated, path_name, output_type: 'png')
        end
      end

      def query(stmt)
        knitter.db.query(stmt)
      end
    end

    class Cache
      attr :db, :options, :file

      def initialize(db, file)
        @db = db
        @file = file
      end

      def cache_file_path(str)
        cache_dir + hash_it(str)
      end

      def fetch_or_create(str, &block)
        cache_file = cache_file_path(str)
        return cache_file.read if cache_file.exist?
        #p ["cache miss for", str, cache_file]
        output = block.call(cache_file)
        cache_file.write(output) unless cache_file.exist?
        cache_file.read
      end

      def remove
        cache_dir.rmtree if cache_dir.exist?
      end

      def cache_dir
        @cache_dir ||= (file.dirname + ".#{hash_it(hash_fodder)}").tap { |d| d.mkpath }
      end

      def hash_fodder
        (db_opts.inspect + file.basename.to_s)
      end

      def db_opts
        db.opts.values_at(*%i(adapter user password host database search_path))
      end

      def hash_it(str)
        Digest::SHA256.hexdigest("#{str}")
      end
    end

    def dir
      file.dirname
    end

    def cache
      @cache ||= Cache.new(db.db, file)
    end

    def hash(obj)
      obj.to_s + db.opts.inspect
    end
  end
end
