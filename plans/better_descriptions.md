# ConceptQL Operator Descriptions Improvement Plan

## Overview

This document outlines the work done to improve operator descriptions in the ConceptQL library.

## Status: Complete

The JSON file at `claude_stuff/operator_descriptions.json` has been created with all 40 operators documented.

## Goals

1. Create clearer, more consistent descriptions for all operators
2. Add practical examples showing ConceptQL syntax
3. Add input/output data examples showing how records transform
4. Document accepted keywords/options for operators that require them

## Deliverable

A JSON file at `claude_stuff/operator_descriptions.json` containing:

- **operator_name**: The operator's name
- **old_description**: Current description from the codebase
- **new_description**: Revised, clearer description
- **example**: ConceptQL JSON syntax example
- **example_explanation**: Plain English explanation of the example
- **example_input** or **database_state**: Sample input data (depending on operator type)
- **example_output**: Expected output records
- **output_explanation**: Summary of the transformation logic
- **options** (where applicable): Accepted keywords, parameters, or options

## Operator Categories

### Source Operators (no upstream input)

These operators select directly from database tables and use `database_state` to show what's in the database:

- **Date Range** - Creates records for all persons with specified dates
- **Death** - Selects from death table
- **Ethnicity** - Selects from person table by ethnicity
- **Gender** - Selects from person table by gender
- **Hospice** - Selects hospice admissions
- **Hospitalization** - Selects inpatient admissions
- **Information Periods** - Selects observation periods (can also take upstream)
- **Multiple Vocabularies** - Selects from clinical codes across vocabularies
- **Race** - Selects from person table by race
- **Read** - Selects by Read vocabulary codes
- **SNF** - Selects skilled nursing facility admissions
- **Vocabulary** - Selects by vocabulary codes (icd9, cpt, ndc, etc.)

### Filter Operators (single upstream)

These operators filter an incoming stream and use `example_input.stream`:

- **Count** - Counts duplicates
- **Dedup** - Removes duplicates
- **Episode** - Merges records into episodes
- **First** - Returns earliest record per person
- **Last** - Returns most recent record per person
- **Numeric** - Sets value_as_number
- **Numeric Filter** - Filters by value_as_number range
- **Occurrence** - Returns nth record per person
- **Place Of Service Filter** - Filters by place of service codes
- **Provenance** - Filters by provenance type
- **Provider Filter** - Filters by provider specialty
- **Sum** - Sums value_as_number
- **Time Window** - Adjusts date ranges

### Binary Operators (left/right inputs)

These operators take two streams and use `example_input.left_stream` and `example_input.right_stream`:

- **After** - Left records starting after right records end
- **Any Overlap** - Left records overlapping with right records
- **Before** - Left records ending before right records start
- **Contains** - Left records containing right records' date range
- **During** - Left records within right records' date range
- **Equal** - Left records matching right records' value_as_number
- **Except** - Left records not in right records
- **Filter** - Left records matching right records' identifiers
- **Match** - Left records with corresponding right records
- **Person Filter** - Left records for people in right records
- **Trim Date** - Truncates left dates based on right dates
- **Trim Date End** - Truncates left end dates
- **Trim Date Start** - Truncates left start dates

### Multi-Stream Operators

- **Co Reported** - Records appearing together in source data
- **Concurrent Within** - Records with overlapping date ranges
- **One In Two Out** - Validates events (1 inpatient or 2 outpatient)
- **Union** - Combines multiple streams

### Utility Operators

- **Person** - Converts records to person records
- **Recall** - References labeled operator output

## Operators with Specific Keywords/Options

### Gender
```
options: ["Male", "Female", "Unknown"]
```

### Ethnicity
```
options: ["Hispanic or Latino", "Not Hispanic or Latino"]
```

### Race
```
options: Race vocabulary codes (e.g., "White", "Black or African American", "Asian", etc.)
```

### Provenance
```
options: Provenance concept codes from the database vocabulary
Examples: "inpatient", "outpatient", "carrier", or concept IDs like "38000204"
```

### One In Two Out
```
options:
  - inpatient_length_of_stay: integer (default: 0)
  - outpatient_minimum_gap: string (default: "30d")
  - outpatient_maximum_gap: string (default: "365d")
  - outpatient_event_to_return: "Initial Event" | "Confirming Event" (default: "Confirming Event")
```

### Time Window
```
options:
  - start: date adjustment string (e.g., "-30d", "1y", "-2m")
  - end: date adjustment string
```

### Date Range
```
options:
  - start: date string (YYYY-MM-DD format)
  - end: date string (YYYY-MM-DD format)
```

### Numeric Filter
```
options:
  - greater_than_or_equal_to: float
  - less_than_or_equal_to: float
```

### Episode
```
options:
  - gap_of: integer (days between records to merge into same episode)
```

### Occurrence
```
options:
  - at_least: date adjustment (minimum gap from previous occurrence)
  - within: date adjustment (maximum gap from previous occurrence)
  - group_by_date: boolean
```

### Temporal Operators (After, Before, During, Contains, Any Overlap)
```
options:
  - within: date adjustment (maximum distance between records)
  - at_least: date adjustment (minimum distance, for After/Before only)
```

### Provider Filter
```
options:
  - specialties: comma-separated specialty concept IDs (required)
  - roles: comma-separated role concept IDs or "*" (required)
```

### Concurrent Within
```
options:
  - start: date adjustment for start date
  - end: date adjustment for end date
```

## Date Adjustment Format

Many operators accept date adjustment strings in the format:
- `Nd` - N days (e.g., "30d", "-7d")
- `Nw` - N weeks
- `Nm` - N months
- `Ny` - N years

Negative values move backward in time, positive values move forward.

## Example Record Structure

ConceptQL records typically contain:
- `person_id` - Patient identifier
- `criterion_id` - Record identifier
- `criterion_domain` - Type of record (condition_occurrence, drug_exposure, etc.)
- `start_date` - Record start date
- `end_date` - Record end date
- `source_value` - Original code value
- `value_as_number` - Numeric value (for counts, measurements, etc.)
- `provenance` - Data source type
- `context_id` - Source record identifier (for co-reported)

## Implementation Notes

- Source operators show `database_state` instead of `example_input`
- Filter/transform operators show `example_input.stream`
- Binary operators show `example_input.left_stream` and `example_input.right_stream`
- Output comments explain why records were kept or excluded
