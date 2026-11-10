---
id: conceptql-3z1
title: scope_annotate loses errors, warnings and counts when two operators share a name
status: captured
type: question
created_at: 2026-11-10T14:59:08.536367+00:00
updated_at: 2026-11-10T14:59:08.536367+00:00
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
