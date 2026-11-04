# ConceptQL::DiagramRenderer

ConceptQL::DiagramRenderer draws a ConceptQL diagram tree as a standalone static SVG, as a PNG,
or as the in-app SVG that a page shows and scripts. It is a Ruby port of the JavaScript renderer
of the Jigsaw diagram editor (`frontend/lib/conceptql-diagram` in the jigsaw-diagram-editor
repository: `src/renderer.js`, `src/geometry.js` and the static exporter
`cli/src/render-static.js`). The comments in the code name those files by their paths in that
repository.

It uses the Ruby standard library only, plus the [resvg](https://github.com/linebender/resvg)
program, which it runs as a subprocess. It does not reference Rails or ActiveSupport.
`lib/conceptql.rb` autoloads it, so `require "conceptql"` loads none of it until the first use of
`ConceptQL::DiagramRenderer`.

## The JavaScript references

The JavaScript renderer wrote the reference output of every fixture under
`test/diagram_renderer/fixtures/statements`. The tests in `test/diagram_renderer/` compare the
Ruby output with those files: the same elements in the same order, the same attributes, and
numbers equal to 6 decimal places (`test/diagram_renderer/svg_comparison.rb`). When the two
disagree, the Ruby code is wrong. Never edit a reference to make a test pass.

A reference holds each `<style>` text as its digest (`sha256:<hex>`). The digests are those of
the gem's `diagram.css`. When the editor's page rules were removed from it, only these digests
changed in the references.

`just test-diagram` runs these tests on the host. They need no database, and they need resvg
0.33.0 exactly (`ConceptQL::DiagramRenderer::Resvg::VERSION`), which `mise.toml` pins and
`just setup` installs. resvg 0.34 measures the bounding box without the stroke, so the viewBox of
none of the 70 fixtures matches. `just test-diagram` fails when resvg is missing or is another
version. `just ci` runs it, and so does the GitHub CI job `Run-Diagram-Renderer-Tests`, which
installs resvg with `.github/install-resvg.sh`. `test/all.rb` leaves these tests out, because the Postgres docker
image and the DuckDB runs have no resvg.

`render_static` and `png` also check the version of resvg. The first call in a process runs
`resvg --version`. When resvg reports another version than 0.33.0, that call writes one warning to
stderr and then draws the diagram anyway. The warning names both versions:

```text
ConceptQL::DiagramRenderer: resvg 0.34.0 is not the required version 0.33.0. The diagrams can be wrong.
```

Later calls in the same process do not check again, and `configure` does not reset the check.

## Input

The input is parsed JSON (hashes with string keys) in one of three shapes:

- a bare node: `{"name" => "icd9", "base" => "selection", "humanName" => "ICD-9 CM", "outputTypes" => ["condition_occurrence"], "values" => ["412"], "children" => []}`
- an array of statements: `[node, node, ...]`
- the output of `conceptql render_json`: `{"format" => "conceptql-diagram/v1", "statements" => [node, ...]}`

The same shapes with symbol keys are read as the JSON strings they become. So the output of
`ConceptQL::Diagram.render` goes in as it is:

```ruby
svg = ConceptQL::DiagramRenderer.render_static(ConceptQL::Diagram.render([ [ "icd9", "412" ] ]))
```

A node has `name` (required), `base`, `humanName`, `vocabularyId`, `outputTypes`, `values`,
`parameters`, `children`, `errors`, `warnings` and `counts`
(`{<stream type> => {"rows" => ..., "n" => ...}}`). `ConceptQL::DiagramRenderer::DiagramData.from`
puts the statements under a synthetic root and gives each node an id. A bad input raises
`ConceptQL::DiagramRenderer::InputError`, with the message of the JavaScript.

## Entry points

```ruby
svg = ConceptQL::DiagramRenderer.render_static(tree, show_counts: false, show_options: false) # => SVG text
png = ConceptQL::DiagramRenderer.png(tree, show_counts: false, show_options: false)           # => PNG bytes
```

- `show_counts` labels each stream with its child's counts.
- `show_options` lists each node's options under its values.

The PNG has the width and height of the SVG. The SVG is static: it does not animate.

## The in-app SVG

```ruby
svg = ConceptQL::DiagramRenderer.render_app(tree, lock_nodes: false, summary: false, show_counts: false,
  show_options: false, css_transforms: false, styles: css, icons: sprite) # => SVG text
```

`render_app` writes the `<svg class="vis">` element that `src/renderer.js` builds at duration 0.
Its input is a tree whose nodes already have ids, `isSelected` and `isAttachable` (the tree that
the editor's Ember client passes to the renderer, or the output of `DiagramData.from`). It is
drawn as it is.

- `lock_nodes` adds the `is-new` class, which hides the "+" insert buttons.
- `summary` adds the fixed `viewBox="0 0 800 500"` of the summary preview.
- `styles` is the CSS of the `<style>` element. The default is the configuration's `styles_path`.
  In a browser page, the rules of an inline SVG's `<style>` apply to the whole page.
- `icons` is the sprite markup, copied into a hidden `<div>`. The default is the content of the
  configuration's `sprite_path` (the content of its `<div class="operators">` block, if it has
  one). The copy leaves out `xmlns="http://www.w3.org/2000/svg"`, as the browser's serializer
  does.
- The `.vis-algorithm` group has no transform: fit-to-view stays in the browser.

Four data attributes are for the browser client. The JavaScript references do not have them:

- `data-node-id` on each node group (`.vis-node`): the id that a click on the node reports.
- `data-insert-before` on each "+" insert button (`.vis-link-new`), when `lock_nodes` is false:
  the id of the node that the button inserts before.
- `data-diagram-key` on each element that an animation moves (`Drawing::MOVED`: `.vis-link`,
  `.vis-link-new`, `.vis-link-path` and `.vis-node`). The renderer gives these elements no id. The
  key is made from node ids, as the D3 joins key them (`node:<id>`, `link:<source id>-<target id>`,
  `link-new:<source id>-<target id>`, `link-path:<source id>-<target id>:<stream index>`). So a
  node keeps its keys across renders of trees that keep its id.
- `data-recall-node-ids` on each recall arc (`.vis-connect`): a JSON array of the ids of the nodes
  whose hover shows the recall arcs. These are the nodes that `isRecalled` in `src/renderer.js`
  matches with the arc: each recall node whose first value is the arc's label, and each node with
  that label.

With `css_transforms: true`, each of those moved elements gets
`style="transform: translate(Xpx, Ypx)"` in place of its `transform` attribute, because CSS
transitions cannot animate the SVG `transform` attribute. The match rule applies with the option
off.

## Assets

The gem ships the assets under `assets/diagram/`, and the configuration points at them by default.
A host needs no configure call:

- `operators.svg`: the operator icon `<symbol>`s. It is the content of the hidden
  `<div class="operators">` block of the editor's `frontend/index.html`, byte for byte, because
  the app references hash the sprite as the browser serializes it.
- `diagram.css`: the diagram CSS. It holds the rules of the editor's `lib/diagram_styles.css`
  whose selectors can match an element that the renderer draws. The editor's page rules (for
  `html`, `body`, `h1`, `.sidebar` and the like) are left out.
- `fonts/Roboto-Normal-Latin.woff2`, `fonts/Roboto-Italic-Latin.woff2`: the Roboto webfonts that
  the SVG embeds.
- `fonts/Roboto-400.ttf`, `fonts/Roboto-700.ttf`, `fonts/Roboto-Italic-400.ttf`: the Roboto files
  for resvg.
- `fonts/OFL.txt`: the license of the five font files, the SIL Open Font License 1.1. Each file's
  name table names that license, and its copyright is the Roboto Project Authors'.

A host that has its own copy of an asset sets that path. The others keep their defaults:

```ruby
ConceptQL::DiagramRenderer.configure do |config|
  config.sprite_path = "my/operators.svg"   # a file with the operator icon <symbol>s, or an HTML page with a <div class="operators"> block
  config.styles_path = "my/diagram.css"     # the diagram CSS
  config.webfonts_dir = "my/fonts"          # Roboto-Normal-Latin.woff2, Roboto-Italic-Latin.woff2
  config.resvg_fonts_dir = "my/fonts"       # Roboto-400.ttf, Roboto-700.ttf, Roboto-Italic-400.ttf
  config.resvg_program = "resvg"            # the default: resvg on PATH
end
```

The SVG embeds the webfonts and the CSS in its `<style>`, and inlines only the icon symbols that
the drawing uses. resvg ignores `@font-face`, so it takes the TTF files instead.

## Files

All under `lib/conceptql/diagram_renderer/`:

- `diagram_data.rb`: the input handling (toDiagramData).
- `drawing.rb`: the elements that `renderer.js` draws.
- `static.rb`: the standalone SVG (makeStandalone and fitToContent).
- `app.rb`: the in-app SVG (the renderer's svg, style and sprite copy).
- `geometry.rb`, `tree_layout.rb`: layout, paths and labels (geometry.js, d3.tree).
- `js_format.rb`: numbers and values written as JavaScript writes them.
- `svg.rb`: the element tree and XML escaping.
- `sprite.rb`: the icon symbols of the sprite.
- `resvg.rb`: the resvg program (bounding box and PNG).
- `configuration.rb`: the asset paths.
