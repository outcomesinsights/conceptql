# Changelog
All notable changes to this project will be documented in this file.

## 0.1.1 - 2014-09-18

### Added
- Nothing.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Calling Query#sql no longer creates a bunch of temporary tables


## 0.1.0 - 2014-09-04

### Added
- Support for numeric, string, and concept_ids returned in results.
- Many updates to the ConceptQL Specification document.
- Added doc/implementation_notes.md to capture thoughts and bad ideas.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- "Fake" graphs are now drawn correctly.
- bin/conceptql doesn't bomb out drawing "fake" graphs


## 0.0.9 - 2014-09-03

### Added
- Support for MSSQL (SQL Server).

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Removed debug output from Node#namify


## 0.0.8 - 2014-08-28

### Added
- Support for Oracle.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- DateAdjuster/TimeWindow use Sequel's date_arithmetic extension to produce database agnostic date manipulation.
- Breakage from Node#tree in GraphNodifier.
- All tests are back to passing.
- Changed from SHA1 to CRC32 hash since Oracle can't handle table names longer than 30 characters.


## 0.0.6 - 2014-08-23

### Added
- Support for Oracle
- Tree#defined to pass type information between Define and Recall.
- Node#sql to produce SQL for each node.
- Graph includes row count on each edge in the diagram.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Bug in CastingNode that generate SQL returning multiple columns in a subquery.
- Made ruby-graphviz a dependency so calling programs don't bomb out.
- Define now passes rows on through like any other node!
- DateAdjuster/TimeWindow use Sequel's date_arithmetic extension to produce database agnostic date manipulation.
- All tests are back to passing.


## 0.0.5 - 2014-08-19

### Added
- Nothing.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Bug in GraphNodifier not displaying types for `recall` nodes.


## 0.0.4 - 2014-08-19

### Added
- Support for 5 instead of 13 column internal representation of results.
- `define` node, used to create "variables" in ConceptQL.
- `recall` node, used to pull results from "variables" in ConceptQL.

### Deprecated
- Nothing.

### Removed
- Support for 13 column results.
- Dependency on a set of views to run SQL queries.

### Fixed
- Bug where `place_of_service_code` wasn't limited to vocabulary_id 14


## 0.0.3 - 2014-08-12

### Added
- FakeGrapher class to make it easier to generate diagrams with experimental nodes
- fake_graph command has returned to the `conceptql` program
- GraphNodifier now supports:
    - condition_type as condition_occurrence
    - drg as procedure_occurrence
    - vsac as misc

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Tree now runs #deep_symbolize_keys on incoming statements


## 0.0.2 - 2014-07-11

### Added
- Nothing.

### Deprecated
- Nothing.

### Removed
- Several commands from `conceptql` program
    - fake_graph
    - show_db_graph
    - show_and_tell_db

### Fixed
- Nothing.


## 0.0.1 - 2014-07-11

### Added
- This project.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Nothing.

