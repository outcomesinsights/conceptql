---
id: conceptql-3z1
title: scope_annotate loses errors, warnings and counts when two operators share a name
status: captured
type: question
created_at: 2026-11-10T14:59:08.536367+00:00
updated_at: 2026-11-10T16:37:06.568879+00:00
---

## The defect

`Query#scope_annotate` returns `errors`, `warnings` and `counts` as hashes keyed by `options[:id] || op_name` (`Operator#annotate`, `lib/conceptql/operators/operator.rb`). `Scope#add_errors` and `Scope#add_warnings` (`lib/conceptql/scope.rb`) assign with `@errors[key] = ...`. So when two operators have the same name and no id, the second one replaces the first one's list. `Scope#add_counts` uses the same key, so the counts of one domain also collide.

The annotated statement (`Query#annotate`) is correct. Each operator has its own `annotation.errors` and `annotation.warnings`. Only the scope hashes lose data.

Reproduced 2026-11-10 on conceptql 0.7.0 (main at 976a1195), mock DuckDB database, gdm_wide. Script: `claude_stuff/scope-key-collision-probe.rb` in the primary checkout. Log: `claude_stuff/scope-key-collision-probe-20261110-065759.log`.

```
statement: ["union",["icd10cm","C7800"],["icd10cm","ZZZ.99"],["not_an_op","x"]]
scope warnings: {"icd10cm":[["improperly formatted code","ZZZ.99"]]}
scope errors:   {"not_an_op":[["invalid operator","not_an_op"]]}
per-op icd10cm C7800: [["improperly formatted code","C7800"]] null
per-op icd10cm ZZZ.99: [["improperly formatted code","ZZZ.99"]] null
```

The C7800 warning is missing from the scope hash.

## Why it matters

A handoff from the JDE seeds session (JDE seed jde-531, "exploring") reported this. JDE's `Algorithm#update_metadata` stores scope_annotate's errors and warnings with `.to_json` in text columns. The MCP tools `algorithms_create`, `algorithms_update` and `algorithms_show` return those strings. Mark's agent saved the dotless code C7800 and could not see its warning.

Production data (read-only query by the JDE session, 2026-11-10): none of the 3,718 operators in the 1,256 current kept algorithms has an id. So every key is an operator name. 73 of those algorithms have two or more operators with the same name.

Ryan, verbatim (2026-11-10): "honestly, I was expecting jde to do a passthrough of what conceptql generates, so let's take this to conceptql." After the gem change, JDE will pass conceptql's output through as objects, not strings.

## Users of the scope hashes

- conceptql: `cli.rb` (`scope_annotate` command), `Query#validation_errors`, `InvalidStatementError`, `Query#window_table_errors` (iterates `op, op_errors` pairs and prefixes each message with the key), and 16 test files.
- JDE: `app/services/analyze_query.rb` (algorithm save) and `app/services/count_statements.rb` (count_statement MCP tool). `count_statements.rb` already documents the counts collision and reads counts from each operator's `annotation.counts` instead.
- t_shank: does not use scope_annotate.
- The diagram editor gives operators ids, so its keys do not collide. The collision affects statements without ids, which is how algorithms are stored.

## Directions (not ruled)

1. scope_annotate's `errors` and `warnings` become a list, one item for each problem: `{operator, path, message, details}`. This changes the public shape. `validation_errors`, `InvalidStatementError` and `window_table_errors` change with it. JDE changes once.
2. Keep the keyed hash, but append to the list under a shared key. No shape change. The reader still cannot tell which operator a problem came from.
3. Add a new list method beside the unchanged hash. No caller breaks. Two shapes then exist for the same data.

## Open questions

- Which direction?
- Do counts belong in the same fix? Appending does not work for counts, because a reader cannot separate two operators' counts under one key.
- What identifies an operator in a list item when it has no id? A path into the statement (for example `[1, 0]`) is one candidate.

## UPDATE 2026-11-10: annotate verified, options shown with real output

Ryan asked for concrete examples of the current output and of each option, and asked to confirm that plain annotation is not affected. A comparison document was sent to him (claude_stuff/conceptql-3z1-annotation-shapes-20261110.md in the primary checkout, not committed).

Verified on the DuckDB fixture with `["union",["icd9","412","4100"],["icd9","250.00","ZZZ.99"]]`: `Query#annotate` keeps each operator's warnings and counts (48 rows / 37 patients and 1036 / 162). `scope_annotate` keeps only the second icd9's warning and counts. With ids `a` and `b` on the two operators, scope_annotate keeps both. So the work is in scope_annotate only.

Option 2 cannot fix counts: 37 + 162 = 199 patients, but the union has 163 distinct patients.

Option 1 example shape (path is a dig path into the statement):

```json
{"warnings": [
  {"operator": "icd9", "id": null, "path": [1], "message": "improperly formatted code", "details": ["4100"]},
  {"operator": "icd9", "id": null, "path": [2], "message": "improperly formatted code", "details": ["ZZZ.99"]}],
 "counts": [
  {"operator": "union", "id": null, "path": [], "counts": {"condition_occurrence": {"rows": 1084, "n": 163}}},
  {"operator": "icd9", "id": null, "path": [1], "counts": {"condition_occurrence": {"rows": 48, "n": 37}}},
  {"operator": "icd9", "id": null, "path": [2], "counts": {"condition_occurrence": {"rows": 1036, "n": 162}}}]}
```

Recommended to Ryan: option 1, with counts in the same list form. Not ruled.

## UPDATE 2026-11-10: Ryan's second round, and why scope_annotate exists

Ryan: "I find "paths" to be opaque and hard to reason through. I'm wondering if scope-annotate couldn't assign each operator a "key" like "icd9cm-1" and "icd9cm-2" and then use that in something like option 1. The other thought I have is why are we using scope annotate? ... Why not just use normal annotate? Is there a reason why we're using scope annotate? Does anything else use scope annotate? I think scope annotate was specifically created to deliver errors and warnings. And honestly, I personally have never understood why we didn't just stick with annotate."

History: Jeremy Evans added scope_annotate in 7fdda074 (2016-02-06). Its commit message: "This is the method that the API should call to get the errors and counts for all parts of the query, keyed by operator id." It calls annotate and returns the hashes that annotate collected on the side. The design assumed that every operator has an id. The fall-back to the operator name is where the data is lost.

Every caller, 2026-11-10:

- JDE StatementDraft#annotations and the diagram count endpoints (AlgorithmEditorController#counts, AlgorithmsController#count): they call `draft.statements(ids: true)`, which sets each operator's id to its node path ("0.1"). So they never collide.
- JDE Algorithm#update_metadata (algorithm save): no ids, so it collides. It stores errors and warnings as JSON strings.
- JDE CountStatements (count_statement MCP tool): returns both the scope hashes and the annotated statements.
- JDE AnalyzeQueries merges the results of several streams with deep_merge and `v1 + v2`. So two streams that have operators with the same key are also merged by key.
- conceptql: Query#validation_errors (and through it InvalidStatementError, window_table_errors) and the CLI.

Assessment: annotate holds everything that scope_annotate holds, on the right operator. scope_annotate is only a flat index of it. A flat index is useful for two things: "does the statement have any errors?", and a list of problems to show a user or an agent. Both can be computed by walking the annotated statement.

Direction under discussion (not ruled): annotate writes a key into each operator's annotation (its id when it has one, otherwise "<operator>-<n>" in statement order, for example "icd9-1" and "icd9-2"). conceptql derives the list of problems from the annotated statement, and each item names the operator by that key. scope_annotate is retired or becomes a thin wrapper of that list. JDE passes the annotated statement and the list through.

## UPDATE 2026-11-10: Ryan's third round

Ryan, transcribed speech: "your proposal sounds like we're just rewriting scope annotate ... your proposal of doing an annotation and then still flattening all errors and putting them up at the top to me sounds like a reinvention of scope annotate. So, what is the thinking behind this?"

He is right: a flat list built from annotate is scope_annotate built again, correctly. The thinking behind it was convenience for the callers that want every problem in one place: algorithm save (is the statement valid, and the stored messages), the MCP tools, and InvalidStatementError's message. None of them needs a second format. A walk of the annotated tree gives each of them the same answer.

Direction proposed to Ryan (not ruled): annotate is conceptql's only output for errors, warnings and counts. No flat copy and no keys, because each problem stays on its operator. conceptql keeps an internal tree walk for validation_errors and InvalidStatementError. scope_annotate is retired, and JDE moves its callers to annotate.

Ryan's concern about the diagram renderer's intermediate node tree is recorded separately in conceptql-3o5.

## UPDATE 2026-11-10: Ryan prefers retiring scope_annotate; consumer review done

Ryan, transcribed speech: "My impression is we can retire scope annotate and keep annotate as the only output for errors. I'd like to do a code review of whoever's consuming scope annotate to see exactly how easy it is to surface all errors and warnings in order to determine if a for instance if an algorithm is valid or not ... my preference would be to get rid of scope annotate. As it's particularly problematic and solving it isn't straightforward and requires some amount of rewrite anyway. So if Annotate can be a relatively drop-in replacement for it, that'd be great."

Review (document sent to Ryan: claude_stuff/conceptql-3z1-scope-annotate-consumers-20261110.md in the primary checkout; probe log claude_stuff/annotate-walk-probe-20261110-080052.log):

- scope_annotate is annotate plus a return of side hashes, so the expensive work is the same. A tree walk of the annotated statement costs 0.65 ms for 151 operators (mock database), with no database query.
- The walk finds every error and warning, including the ones scope_annotate loses.
- conceptql: validation_errors, validate!/InvalidStatementError, window_table_errors and the CLI command change by a few lines each. 16 test files and 5 scanno\_\* statement tests migrate. InvalidStatementError#errors changes from a hash to a list (breaking, 0.x minor).
- JDE: algorithm save (AnalyzeQueries, update_metadata, and the readers of conceptql_errors and conceptql_warnings), the diagram pages (StatementDraft#annotations, PageDiagram), and the count endpoints. The diagram pages already set unique ids (node paths), so they can index annotate's output by id.
- Proposed: conceptql ships the walk as a public helper that computes from the annotated statement on each call and stores nothing, so JDE need not know where ConceptQL keeps an operator's inputs.

Not yet ruled: Ryan's go-ahead after he reads the review, and whether the walk is a public helper.

## RULED 2026-11-10

Ryan: "Ok, I think we should drop scope_annotate and provide helpers for jde to use. we might even be able to use caching of the annotation at that point to make subsequent helper calls to the same statement go faster?"

- scope_annotate is removed. annotate is conceptql's only output for errors, warnings and counts.
- conceptql provides helpers that read an annotated statement: every operator, every error, every warning, and validity.
- Query caches its annotation by options, so later helper calls on the same Query do not annotate again. Today Operator#annotate keeps the result of its first call and ignores later options, which is why validation_errors builds a fresh Query. The cache replaces that work-around.

Beads, 2026-11-10: conceptql-k7vg (annotation helpers and the per-options annotation cache on Query) and conceptql-si8t (remove scope_annotate; depends on conceptql-k7vg). The helper API in conceptql-k7vg's notes is proposed, not ruled.

## UPDATE 2026-11-10: generated ids, not arguments

The arguments example (claude_stuff/conceptql-k7vg-arguments-example-20261110.md, log claude_stuff/annotation-api-arguments-20261110-083301.log) showed two "has upstreams" errors on two icd9 operators that are identical without `arguments`.

Ryan, transcribed speech: "your proposed solution for annotations API returning errors has simply recreated the very problem we were trying to solve in scope annotation ... what if I have for some reason put the exact same operators, selection operators, in twice? ... You would still get back to identical errors. So, my argument is going to be that if there is no provided ID, we create an ID and send that back when we are doing an annotation. And then we can continue to associate errors to a specific ID and not have to worry about carrying the arguments. Is there any other benefit to carrying the arguments in the error messages outside of just trying to differentiate between like operators."

Answer given: no. The only other use is that a reader sees the codes without a lookup, and with an id `each_operator` gives the lookup. `arguments` is dropped.

Direction (Ryan's): annotate gives every operator an id. A given id is kept. An operator without one gets a generated id. Each error and warning item names its operator by that id.

Details proposed, not ruled:

- The effective id (given or generated) goes into each operator's annotation hash, so a reader looks in one place. The statement's own options are not changed.
- Generated form: `<operator>-<n>` in statement order (`icd9-1`, `icd9-2`), as Ryan suggested earlier. A generated id never repeats a given id.
- One Query annotates one statement, so the numbering is per statement. JDE annotates each stream with its own Query; if JDE joins the lists of several streams, an item must also say its stream.
