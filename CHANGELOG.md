# Changelog
All notable changes to this project will be documented in this file.

## 0.0.6 - 2014-08-20

### Added
- Nothing.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Bug in CastingNode that generate SQL returning multiple columns in a subquery.


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

