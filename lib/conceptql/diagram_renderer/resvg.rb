# frozen_string_literal: true

require "open3"
require "tmpdir"

module ConceptQL
  module DiagramRenderer
    # The resvg command-line program (https://github.com/linebender/resvg), run
    # as a subprocess: the bounding box of a drawing and PNG output.
    # mise.toml pins the release (VERSION) and says why it is that release.
    # resvg is also the engine of the JavaScript static exporter
    # (@resvg/resvg-js in frontend/lib/conceptql-diagram/cli). Both use the same
    # fonts: the three Roboto files, no system fonts, default family Roboto
    # (resvgOptions() in cli/src/render-static.js).
    #
    #   resvg = ConceptQL::DiagramRenderer::Resvg.new(fonts_dir: "assets/diagram/fonts")
    #   resvg.bbox(svg) # => [x, y, width, height]
    #   resvg.png(svg)  # => PNG bytes
    class Resvg
      VERSION = "0.33.0"
      FONT_FILES = %w[Roboto-400.ttf Roboto-700.ttf Roboto-Italic-400.ttf].freeze
      DEFAULT_FONT_FAMILY = "Roboto"
      # The id of the group that bbox wraps around the drawing.
      BBOX_ID = "conceptql-diagram-bbox"
      # The root element's start tag. A quoted attribute value may hold ">".
      ROOT_START = /<svg\b(?:[^>"']|"[^"]*"|'[^']*')*>/

      # A failed run: the program is missing, exits non-zero, or prints no box.
      class Error < StandardError
        attr_reader :command, :status, :stderr

        def initialize(command:, status: nil, stderr: "", reason: nil)
          @command = command
          @status = status
          @stderr = stderr
          exit_text = status ? "exit status #{status}" : "no exit status"
          super([ "resvg failed: #{reason || exit_text}", "command: #{command.join(' ')}", "stderr: #{stderr}" ].join("\n"))
        end
      end

      attr_reader :program, :fonts_dir

      # fonts_dir holds FONT_FILES. program is the resvg executable (a name on
      # PATH or a path).
      def initialize(fonts_dir:, program: "resvg")
        @fonts_dir = fonts_dir.to_s
        @program = program.to_s
      end

      # The version that `resvg --version` prints, e.g. "0.33.0".
      def version
        run([ "--version" ]).strip
      end

      # The bounding box of the whole drawing, in user units, as
      # [x, y, width, height]: what resvg-js getBBox() returns for the same SVG.
      #
      # The CLI has no "box of everything" mode. --query-all prints
      # "id,x,y,width,height" for each element with an id, with text converted
      # to paths and the stroke included, as getBBox() does. The root has no id,
      # so bbox wraps the root's content in one group with BBOX_ID and reads
      # that group's line. In resvg 0.33 the box is in the coordinates of the
      # root's content, so the viewBox and width/height do not change it.
      # --query-all rounds to 3 decimal places. An empty drawing has no box and
      # raises Error.
      def bbox(svg)
        start = svg.match(ROOT_START) or raise ArgumentError, "no <svg> start tag in the input"
        close = svg.rindex("</svg>") or raise ArgumentError, "no </svg> end tag in the input"
        wrapped = "#{svg[0...start.end(0)]}<g id=\"#{BBOX_ID}\">#{svg[start.end(0)...close]}</g>#{svg[close..]}"
        with_input(wrapped) do |input|
          command = [ "--query-all", *font_arguments, input ]
          line = run(command).lines.find { |l| l.start_with?("#{BBOX_ID},") }
          raise Error.new(command: full(command), status: 0, reason: "no bounding box for ##{BBOX_ID}; the drawing may be empty") unless line

          line.strip.split(",").drop(1).map { |n| Float(n) }
        end
      end

      # The SVG rasterized to PNG bytes, at the size of its width and height.
      def png(svg)
        with_input(svg) do |input|
          output = File.join(File.dirname(input), "out.png")
          run([ *font_arguments, input, output ])
          File.binread(output)
        end
      end

      private

      def font_arguments
        FONT_FILES.flat_map { |f| [ "--use-font-file", File.join(fonts_dir, f) ] } +
          [ "--skip-system-fonts", "--font-family", DEFAULT_FONT_FAMILY ]
      end

      def full(arguments) = [ program, *arguments ]

      # The SVG goes to the program as a file in a new temporary directory, not
      # on stdin: with stdin input, resvg prints a warning to stdout, which
      # would corrupt PNG output on stdout. The directory is also the
      # program's --resources-dir default, so a relative href finds nothing.
      def with_input(svg)
        Dir.mktmpdir("conceptql-diagram-resvg") do |dir|
          input = File.join(dir, "in.svg")
          File.write(input, svg)
          yield input
        end
      end

      def run(arguments)
        command = full(arguments)
        stdout, stderr, status = Open3.capture3(*command)
        raise Error.new(command:, status: status.exitstatus, stderr:) unless status.success?

        stdout
      rescue SystemCallError => e
        raise Error.new(command:, stderr: "", reason: "cannot run #{program}: #{e.message}")
      end
    end
  end
end
