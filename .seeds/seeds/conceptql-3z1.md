---
id: conceptql-3z1
title: scope_annotate loses errors, warnings and counts when two operators share a name
status: captured
type: question
created_at: 2026-11-10T14:59:08.536367+00:00
updated_at: 2026-11-10T15:48:30.747310+00:00
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
