---
id: conceptql-ufn
title: Options and arguments that the metadata offers but the code ignores (equal within, first/last group_by_date, information_periods arguments)
status: captured
type: question
created_at: 2026-11-04T00:12:41.925927+00:00
updated_at: 2026-11-04T00:13:25.036387+00:00
---

## Context

During the spec-migration bead run (epic conceptql-jwsv, 2026-11-03), the agents that wrote the
operator reference texts found three options or arguments that the metadata offers but that the
code does not use as offered. Each agent documented the code as it is and changed no behavior.

## The three items

1. **equal: the within option has no effect.** Equal inherits within from TemporalOperator, and
   Equal#where_clause compares only value_as_number. The jwsv.7 text says "Equal does not compare
   dates, so this option has no effect." The editor still offers the option.
2. **first and last: the group_by_date option does not change the result.** Both inherit
   group_by_date from Occurrence. The jwsv.8 agent ran first and last with and without it on the
   DuckDB fixture: 163 rows both ways. first.rb and last.rb already mark at_least and within as
   unsupported_options.
3. **information_periods: the operator takes arguments but declares none.** Each argument is an
   information type concept ID (gdm.rb information_period_where_clause maps them to_i). Because
   no argument is declared, an editor cannot offer the field. The jwsv.9 agent explained the
   arguments in the desc and did not declare one, because a declaration changes the editor.

## Existing mechanism

operator.rb `unsupported_options(*names)` removes the option from the metadata and adds a
validation that fails when the option is non-blank. except.rb, filter.rb, person_filter.rb,
first.rb and last.rb use it today.

## Options

- Items 1 and 2: (a) mark the option with unsupported_options. The editor stops offering it, and
  a saved statement that sets it stops validating, so its author sees the problem. This matches
  Ryan's 2026-11-03 ruling on stray upstreams ("A saved statement with such an upstream stops
  validating, so its author sees the problem instead of a silently dropped criterion").
  (b) Keep the option and the current text that says it has no effect.
- Item 3: (a) declare the argument (integer concept IDs), so the editor offers it.
  (b) Leave it undeclared and keep the desc text.

## Related ruling recorded today

RULED 2026-11-03 (Ryan): occurrence, first and last take exactly one upstream: "about occurrence,
yes, only one upstream". A second positional upstream becomes a validation error, and their
metadata reports 1/1.

RULED 2026-11-03 (Ryan, through AskUserQuestion): items 1 and 2: mark unsupported. equal's within and first/last's group_by_date use unsupported_options: the editor stops offering them, and a saved statement that sets them gets a validation error. Item 3: declare the argument. information_periods declares an integer argument for information type concept IDs, so the editor offers the field.
