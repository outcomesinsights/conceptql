# Bug: Column introspection on nonexistent temp tables during evaluate

## Summary

After updating to the latest conceptql commit (`770e3db`), t_shank export tests fail with 139 failures. All failures have the same root cause: during `op.evaluate(db)`, Sequel executes a live database query to discover columns on a temp table that hasn't been created yet.

Rolling back `Gemfile.lock` to the prior conceptql revision (`7187057`) with the exact same t_shank code produces 0 failures.

## Error

```
ConceptQL::Query::QueryError:
  Failed to generate SQL for [:any_overlap, {
    left: [:from, QualifiedIdentifier("jigsaw_temp", :jtemph67irb_baseline_windows_after_inclusion),
           {query_cols: [:person_id, :criterion_id, ...]}],
    right: ["icd9", "493.90"]
  }]
  OG ERROR:
  PG::UndefinedTable: ERROR: relation "jigsaw_temp.jtemph67irb_baseline_windows_after_inclusion" does not exist
```

## Failure chain (stack trace)

```
scope.rb:318         op.evaluate(db)
  operator.rb:214      select_it(query(db))        — From#query returns db.from(table_name)
    windowable.rb:12     window.call(self, ds, ...)
      window/table.rb:42   remove_window_id(query)
        window/table.rb:61   ds.select_remove(:window_id)   — needs column list
          select_remove.rb:46  columns!                      — queries the DB
            postgres.rb:171      PG::UndefinedTable           — table doesn't exist
```

## Context: How t_shank uses ConceptQL

T_shank's export runner processes tables in dependency order. For each table:

1. Calls `table.sql_statements(runner)` which invokes `ConceptQL::Query#sql_statements`
2. `sql_statements` calls `scope.with_ctes(op, db)` which calls `op.evaluate(db)` (scope.rb:318)
3. The evaluate phase builds Sequel datasets for the entire operator tree
4. Some operators reference temp tables created by **prior** runner steps (via `From` operator with a qualified identifier like `jigsaw_temp.some_table`)
5. Those prior tables DO exist in the database — they were created by earlier `CREATE TABLE ... AS` calls

The problem occurs when an operator in the tree triggers **live column introspection** on a dataset backed by one of these temp tables.

## Root cause: `select_remove` triggers `columns` on a bare dataset

The `From` operator's `query` method returns `db.from(table_name)` — a bare dataset with **no explicit column selection**:

```ruby
# from.rb:17
def query(db)
  db.from(table_name)
end
```

When this dataset flows through `Windowable#select_it` → `Window::Table#call` → `remove_window_id`, it hits:

```ruby
# window/table.rb:57
def remove_window_id(ds)
  if (cols = selected_columns(ds)) && cols.all? { |s| s.is_a?(Symbol) }
    ds.select(*(cols - [:window_id]))
  else
    ds.select_remove(:window_id)     # <-- THIS PATH
  end
end
```

`selected_columns(ds)` returns nil because the dataset has no explicit SELECT. So it falls through to `select_remove(:window_id)`, which calls Sequel's `columns` method, which executes `SELECT * FROM table LIMIT 0` against the database.

For most tables, this works because they exist in the database. But for temp tables referenced via `From` (created by prior t_shank steps), this only works if the table was actually created. The issue is timing — something in the new code causes this introspection to happen when it didn't before, OR the table that should exist doesn't.

## What changed in the conceptql commit

Commit `5d0983aa` ("Fix DuckDB full statement suite support") made these changes to `scope.rb`:

### 1. CTE extraction runs before `force_temp_tables?` check
The old code ran CTE extraction conditionally. The new code always runs `recursive_extract_ctes` and `sort_extracted_ctes` first.

### 2. New `sort_extracted_ctes` method
```ruby
def sort_extracted_ctes(ctes)
  ctes = ctes.uniq(&:first)
  deps = ctes.each_with_object({}) do |(name, ds), memo|
    sql = ds.sql            # <-- calls .sql on every CTE dataset
    memo[name] = ctes.filter_map do |(other_name, _)|
      next if other_name == name
      other_name if sql.include?(%("#{other_name}"))
    end
  end
  sort_ctes([], ctes, deps)
end
```

This calls `ds.sql` on every extracted CTE to determine dependency order. If any CTE dataset triggers column introspection during `.sql` generation (e.g., because it contains `select_remove`), this would fail for the same reason.

### 3. CTEs now carry `with_opts` as 3-tuples
`temp_tables` changed from `[name, dataset]` to `[name, dataset, with_opts]`. The `with_opts` includes `:materialized => true` for PostgreSQL. These options are now passed through to `query.with(name, ds, with_opts)`.

## Investigation needed

The key question: **why did the old code avoid triggering `columns` during evaluate?**

Possibilities:
1. **The From operator's dataset was different** — maybe old code produced a dataset with explicit columns that `selected_columns` could find, avoiding the `select_remove` fallback
2. **The evaluation order changed** — `sort_extracted_ctes` or the extraction reorder means a different operator is now evaluated first, before its dependency table exists
3. **`sort_extracted_ctes` triggers the introspection** — calling `ds.sql` on CTEs during sorting may trigger `select_remove` → `columns` on datasets that reference not-yet-created tables
4. **The `with_opts` materialization changes the SQL path** — passing `:materialized => true` to `.with()` may change how Sequel resolves column references

## The `cold_col` extension — likely the real fix

The `cold_col` Sequel extension (in both sequelizer and conceptql) solves exactly this problem. It overrides `Dataset#columns` to resolve column information from an in-memory registry instead of querying the database:

- Auto-records schemas when `CREATE TABLE AS` and `CREATE VIEW` are executed
- Resolves columns from CTEs, aliases, JOINs, and the registry
- Falls back through: created views → created tables → loaded schemas

**ConceptQL already has it** but only loads it for mock databases by default:
```ruby
# conceptql/lib/conceptql/database.rb:72
use_cold_col = db.is_a?(Sequel::Mock::Database) if use_cold_col.nil?
return unless use_cold_col
db.extension(:cold_col)
```

**T_shank does not use it at all.**

If `cold_col` were loaded on t_shank's real database connections, the failure chain would be broken: `select_remove` → `columns` would resolve from the registry (which knows about temp tables created by prior export steps via `create_table_as` hooks) instead of executing SQL against the database.

### Why this is the right fix

The `cold_col` extension was specifically designed for this scenario — determining column information without live database queries. The bug exists because ConceptQL's operator evaluation can trigger column introspection during SQL generation, before the referenced tables are created. `cold_col` decouples column resolution from table existence.

### Where to load it

**Option 1: In t_shank's test harness** — `AllExportsSpecManager#db` or `ExportTest#db` could call `db.extension(:cold_col)`. This fixes the test failures without changing production behavior.

**Option 2: In ConceptQL** — change the `use_cold_col` default from `nil` (mock-only) to `true` (always). This would make all ConceptQL consumers benefit, but may have side effects for consumers that don't create tables via `CREATE TABLE AS` (the auto-recording hook).

**Option 3: In t_shank's adapter** — `RdbmsAdapter::Postgres#prep_for_export` (and DuckDB) could load `cold_col`. This fixes both tests and production.

## Other possible fixes (less targeted)

### Fix A: Make `From` operator specify explicit columns
Since `From` has `query_cols` (via `override_columns`), its `query` method could specify them:
```ruby
def query(db)
  cols = options[:query_cols]&.map(&:to_sym)
  ds = db.from(table_name)
  cols ? ds.select(*cols) : ds
end
```
This would make `selected_columns(ds)` in `Window::Table` return the columns, avoiding the `select_remove` fallback entirely. However, this may change the SQL for ALL From operators, not just the problematic ones.

### Fix B: Make `remove_window_id` use `required_columns` from the operator
Instead of introspecting the dataset, use the operator's known column list:
```ruby
def remove_window_id(ds)
  if (cols = selected_columns(ds)) && cols.all? { |s| s.is_a?(Symbol) }
    ds.select(*(cols - [:window_id]))
  else
    ds.select_remove(:window_id)
  end
end
```
This already tries `selected_columns` first. The issue is that `selected_columns` can't find columns because the dataset has no explicit select. Fix A would resolve this.

### Fix C: Make `sort_extracted_ctes` not trigger column introspection
Use `ds.unfiltered.unordered.clone(select: nil).sql` or a simpler SQL generation that doesn't trigger column resolution. Or track dependencies via the operator tree instead of generated SQL.

### Fix D: Make `selectify` happen before window handling
`operator.rb:214` calls `select_it(query(db))` which goes through Windowable THEN through the base `select_it` which calls `dm.selectify(query, opts)`. The selectify adds explicit columns. If selectify ran first (before window handling), the dataset would have explicit columns and `remove_window_id` wouldn't need to introspect.

## Reproduction

```bash
# In t_shank, update Gemfile.lock to latest gem revisions:
cd /home/ryan/projects/outins/jigsaw/main/t_shank
bundle update conceptql sequelizer sequel-duckdb

# Run tests — 139 failures
cd /home/ryan/projects/outins/jigsaw/main
just test-tshank

# Restore old Gemfile.lock — 0 failures
cd /home/ryan/projects/outins/jigsaw/main/t_shank
git checkout Gemfile.lock
cd /home/ryan/projects/outins/jigsaw/main
just test-tshank
```

## Gem revisions

| Gem | Working revision | Failing revision |
|-----|-----------------|-----------------|
| conceptql | `7187057f68f01c6af3d7ef60fe316d133b13c752` | `770e3db772754daab52529b1112b7db9f53a4f39` |
| sequel-duckdb | `72f8e32e556f49fff8d88fcbcf481661b5db210f` | `c9be40d8e0d43ea12ad5a72e7e09fd8e53d79db0` |
| sequelizer | `4d6fccd704ec83452649f95a6c26a231ae1c3a3b` | `84ab55a7f5e572869c40a70ee37a2a3c54321477` |

The conceptql change is almost certainly the cause. The sequel-duckdb and sequelizer changes are minor (schema qualification support and adapter discovery refactoring respectively).
