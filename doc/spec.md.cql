# ConceptQL Specification

ConceptQL (pronounced concept-Q-L) is a high-level language that allows researchers to unambiguously define their research algorithms.

## Motivation for ConceptQL

Outcomes Insights intends to build a vast library of research algorithms and apply those algorithms to large databases of claims data.  Early into building the library, we realized we had to overcome two major issues:

1. Methods sections of research papers commonly use natural language to specify the criteria used to build cohorts from a claims database.
    - Algorithms defined in natural language are often imprecise, open to multiple interpretations, and generally difficult to reproduce.
    - Researchers could benefit from a language that removes the ambiguity of natural language while increasing the reproducibility of their research algorithms.
1. Querying against claims databases is often difficult.
    - Hand-coding algorithms to extract cohorts from datasets is time-consuming, error-prone, and opaque.
    - Researchers could benefit from a language that allows algorithms to be defined at a high-level and then gets translated into the appropriate queries against a database.

We developed ConceptQL to address these two issues.

We are writing a tool that can read research algorithms defined in ConceptQL.  The tool can create a diagram for the algorithm which makes it easy to visualize and understand.  The tool can also translate the algorithm into a SQL query which runs against data structured in the Generalized Data Model (GDM).  GDM standardizes the format of observational healthcare data, such as claims, so that the same algorithm can run against many data sources.

GDM keeps the data in a small number of tables:

- patients
    - One row for each patient, with the date of birth, gender, race, and ethnicity
- clinical_codes
    - One row for each code that a source record reports for a patient, such as a diagnosis, a procedure, a drug, or a lab test, with a start date and an end date
- contexts
    - One row for each source record, such as a claim or a claim line
    - Each clinical code points at the context that reported it
- collections
    - One row for each group of contexts, such as a hospital stay
- information_periods
    - The date ranges for which the data source has information about a patient
- deaths
    - One row for each recorded death

ConceptQL supports two variants of GDM.  The data model `gdm` reads clinical codes from clinical_codes.  The data model `gdm_wide` reads them from observations, a wide table that holds the same rows as clinical_codes with the columns of their contexts and collections joined on.  ConceptQL looks up codes, such as ICD-9 412, in a vocabulary database to find their concept IDs.

For instance, using ConceptQL we can take a statement that looks like this:

```YAML
- icd9
- '412'
```

And generate a diagram that looks like this:

```ConceptQL
[
  "icd9",
  "412"
]
```

And generate SQL that looks like this (simplified from the SQL that ConceptQL generates for `gdm_wide`, where 44820864 is the concept ID of ICD-9 412):

```SQL
SELECT
  "patient_id" AS "person_id",
  "id" AS "criterion_id",
  'observations' AS "criterion_table",
  'condition_occurrence' AS "criterion_domain",
  "start_date",
  "end_date",
  "clinical_code_source_value" AS "source_value"
FROM "observations"
WHERE "clinical_code_vocabulary_id" = 'ICD9CM'
  AND "clinical_code_concept_id" IN (44820864)
```

As stated above, one of the goals of ConceptQL is to make it easy to assemble fairly complex queries without having to roll up our sleeves and write raw SQL.  To accommodate this complexity, ConceptQL itself has some complexities of its own.  That said, we believe ConceptQL will help researchers define, hone, and share their research algorithms.

## ConceptQL Overview

### What ConceptQL Looks Like

I find seeing examples to be the quickest way to get a sense of a language.  Here is a trivial example to whet your appetite.  The example is in YAML, but could just as easily be in JSON or any other markup language capable of representing nested sets of heterogeneous arrays and hashes.  In fact, the ConceptQL "language" is a just set of nested hashes and arrays representing search criteria and some set operations and temporal operations to glue those criteria together.

```YAML
# Example 1: A simple example in YAML
# This is just a simple array: the name of an operator, icd9, followed by its argument, 412
# This example will search the clinical codes for all conditions that match the ICD-9 code 412.
---
- icd9
- '412'
```

### ConceptQL Diagrams

Reading ConceptQL in YAML or JSON seems hard to me.  I prefer to explore ConceptQL using directed graphs.  For instance, the diagram for the simple example listed in YAML above is:

```ConceptQL
# All Conditions Matching MI
[
  "icd9",
  "412"
]
```

Each oval depicts a "operator", or rather, a ConceptQL expression.  An arrow between a pair of operators indicates that the results from the operator on the tail of the arrow pass on to the operator at the head of the arrow.  A simple example should help here:

```ConceptQL
# First Office Visit Per Patient
[
  "first",
  [
    "cpt",
    "99214"
  ]
]
```

The diagram above reads "get all procedures that match the CPT 99214 (Office Visit) and then filter them down to the first occurrence for each person".  The diagram is much more terse than that and to accurately read the diagram, you need a lot of implicit knowledge about how each operator operates.  Fortunately, this document will (hopefully) impart that knowledge to you.

Please note that all of my diagrams end with an arrow pointing at nothing.  You'll see why soon.

### Think of Results as a Stream

I draw my ConceptQL diagrams with leaf operators at the top and the "trunk" operators at the bottom.  I like to think of the results of a ConceptQL statement as a flowing stream of data.  The leaf operators, or operators that gather results out of the database, act like tributaries.  The results flow downwards and either join with other results, or filter out other results until the streams emerge at the bottom of the diagram.  Think of each arrow as a stream of results, flowing down through one operator to the next.

The trailing arrow in the diagrams serves as a reminder that ConceptQL yields a stream of results.

### Streams have Types

You might have noticed that the operators and edges in the diagrams often have a color.  That color represents what "type" of stream the operator or edge represents.  A stream's type is the domain of its results.  Each result reports its type in the criterion_domain column.  These are the most common types, with their colors in the diagrams:

- condition_occurrence
    - red
- death
    - brown
- drug_exposure
    - purple
- observation
    - magenta
- observation_period
    - gray
- person
    - blue
- procedure_occurrence
    - green

A stream that carries more than one type is black.

Each stream has a point of origin: the selection operator that pulled its results out of the database.  Based on that origin, each stream will have a particular type.  The type does not always match the table.  Most results come from the clinical codes table, and a vocabulary operator gives its results the domain of its vocabulary.  For example, `icd9` yields condition_occurrence results and `cpt` yields procedure_occurrence results, but both read the same table.  Results from patients are person results, results from deaths are death results, and results from information_periods are observation_period results.  The stream carries this type information as it moves through each operator.  When certain operators, particularly set and temporal operators, need to perform filtering, they can use this type information to determine how to best filter a stream.  There will be much more discussion about types woven throughout this document.  For now, it is sufficient to know that each stream has a type.

You'll also notice that the trailing arrow(s) at the end of the diagrams indicate which types of streams are ultimately passed on at the end of a ConceptQL statement.

### What *are* Streams Really?

Though I think that a "stream" is a helpful abstraction when thinking in ConceptQL, on a few occasions we need to know what's going on under the hood.

Every table in GDM has a surrogate key column, id.  When we execute a ConceptQL statement, the "streams" that are generated by the statement are just sets of these IDs for rows that matched the ConceptQL criteria.  Each result carries the ID of its row in the criterion_id column and the name of its table of origin in the criterion_table column.  So each stream is just a set of IDs that point back to some rows in the GDM tables.  The "type" of a stream is the criterion_domain of its results.

So when we execute this ConceptQL statement, the resulting "stream" is all the patient IDs for all male patients in the database:

```ConceptQL
# All Male Patients
[
  "gender",
  "Male"
]
```

When we execute this ConceptQL statement, the resulting "stream" is the IDs of all clinical codes that match ICD-9 486 (pneumonia), with the type condition_occurrence:

```ConceptQL
# All Condition Occurrences that match ICD-9 486
[
  "icd9",
  "486"
]
```

Generally, I find it helpful to just think of those queries generating a "stream of people" or a "stream of conditions" and not worry about the table of origin or the fact that they are just IDs.

When a ConceptQL statement is executed, it yields a final set of streams that are just all the IDs that passed through all the criteria.  What is done with that set of IDs is up to the user who assembled the ConceptQL statement.  If a user gathers all 486 Conditions, they will end up with a set of clinical code IDs.  They could take those IDs and do all sorts of things like:

- Gather the first and last date of occurrence per person
- Count the number of occurrences per person
- Count number of persons with the condition
- Count the total number of occurrences for the entire population

This kind of aggregation and analysis is beyond the scope of ConceptQL.  ConceptQL will get you the IDs of the rows you're interested in, its up to other parts of the calling system to determine what you do with them.

## Selection Operators

Selection operators are the parts of a ConceptQL query that search for specific values within the GDM data, e.g. searching the clinical codes for a diagnosis of an old myocardial infarction (ICD-9 412) is a selection.  Selection operators are always leaf operators.

There are _many_ selection operators.  A list of currently implemented operators is available in Appendix A.

## All Other Operators i.e. Mutation Operators

Virtually all other operators add, remove, filter, or otherwise alter streams of results.  They are discussed in this section.

## Set Operators

Because streams represent sets of results, its makes sense to include a operators that operate on sets.  ConceptQL has three of them: union, filter, and except.  It has no intersect operator and no complement operator.

### Union

- Takes any number of upstream operators and aggregates their streams
    - Unions together streams with identical types
        - Think of streams with the same type flowing together into a single stream
        - Union does not remove duplicates: a result that arrives from two upstream operators can appear twice
    - Streams with the different types flow along together concurrently without interacting
        - It does not make sense to union, say, condition_occurrence results with procedure_occurrence results, so streams with different types won't mingle together, but will continue to flow downstream in parallel

```ConceptQL
# Two streams of the same type (condition_occurrence) joined into a single stream
[
  "union",
  [
    "icd9",
    "412"
  ],
  [
    "icd9",
    "486"
  ]
]
```

```ConceptQL
# Two streams of the same type (condition_occurrence) joined into a single stream, then a different stream (procedure_occurrence) flows concurrently
[
  "union",
  [
    "union",
    [
      "icd9",
      "412"
    ],
    [
      "icd9",
      "486"
    ]
  ],
  [
    "cpt",
    "99231"
  ]
]
```

```ConceptQL
# Two streams of the same type (condition_occurrence) joined into a single stream, along with a different stream (procedure_occurrence) flows concurrently (same as above example)
[
  "union",
  [
    "icd9",
    "412"
  ],
  [
    "icd9",
    "486"
  ],
  [
    "cpt",
    "99231"
  ]
]
```

### Filter

This operator takes two sets of incoming streams, a left-hand stream and a right-hand stream.  It passes along each left-hand result that also appears in the right-hand stream.  Two results are the same when they have the same person_id, criterion_id, criterion_domain, start_date, and end_date.  The operator discards all results in the right-hand stream.  Use filter to keep only the results that two streams have in common, as an intersection would.

```ConceptQL
# All MI Conditions from inpatient records that also occurred in 2009
[
  "filter",
  {
    "left": [
      "provenance",
      [
        "icd9",
        "412"
      ],
      "inpatient"
    ],
    "right": [
      "during",
      {
        "left": [
          "icd9",
          "412"
        ],
        "right": [
          "date_range",
          {
            "start": "2009-01-01",
            "end": "2009-12-31"
          }
        ]
      }
    ]
  }
]
```

The `provenance` operator in this example passes along the results that come from a given kind of source record, here inpatient records.

### Except

This operator takes two sets of incoming streams, a left-hand stream and a right-hand stream.  The operator removes any results in the left-hand stream if they appear in the right-hand stream.  Two results are the same when they have the same criterion_id, criterion_table, start_date, and end_date.  The operator passes only results for the left-hand stream downstream.  The operator discards all results in the right-hand stream. For example:

```ConceptQL
# All Conditions that are MI unless they come from inpatient records
[
  "except",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "provenance",
      [
        "icd9",
        "412"
      ],
      "inpatient"
    ]
  }
]
```

A result in one stream cannot match a result of a different type, so if the left-hand stream has no types that match the right-hand stream, the left-hand stream passes through unaffected:

```ConceptQL
# All Conditions that are MI
[
  "except",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "cpt",
      "99214"
    ]
  }
]
```

And just to show how multiple streams behave:

```ConceptQL
# Passes three streams downstream: a stream of Conditions that are MI but not from inpatient records, a stream of People that are Male but not White, and a stream of Procedures that are office visits (this stream is completely unaffected by the right hand stream)
[
  "except",
  {
    "left": [
      "union",
      [
        "icd9",
        "412"
      ],
      [
        "gender",
        "Male"
      ],
      [
        "cpt",
        "99214"
      ]
    ],
    "right": [
      "union",
      [
        "provenance",
        [
          "icd9",
          "412"
        ],
        "inpatient"
      ],
      [
        "race",
        "White"
      ]
    ]
  }
]
```

### Discussion about Set Operators

#### Union Operators

##### Q. Why should we allow two different types of streams to continue downstream concurrently?

- This feature lets us do interesting things, like find the first occurrence of either an MI or Death as in the example below
    - Throw in a few more criteria and you could find the first occurrence of all censor events for each patient

```ConceptQL
# First occurrence of either MI or Death for each patient
[
  "first",
  [
    "union",
    [
      "icd9",
      "412"
    ],
    [
      "death"
    ]
  ]
]
```

## Co-reported Events

### co_reported

`co_reported` passes along the events of its upstream streams that were reported in the same source record, for example on the same claim. The source record is the event's context (`context_id`).

A source record is kept only if every upstream stream has at least one event in it. If any one upstream has no event in a record, `co_reported` drops the events of **all** streams in that record. The drop is silent: the operator gives no warning and does not report how many records it removed.

For example, a claim with a diabetes diagnosis and no office-visit procedure contributes nothing to the statement below, not even its diagnosis. In the test data, ICD-9 250.00 has 1,036 events and CPT 99214 has 1,073 events, but only 49 records have both, so `co_reported` returns 98 events.

```ConceptQL
# Yields the diabetes diagnoses and the office-visit procedures that were reported in the same source record
[
  "co_reported",
  [
    "icd9",
    "250.00"
  ],
  [
    "cpt",
    "99214"
  ]
]
```

## Time-oriented Operators

All results in a stream carry a start_date and end_date with them.  All temporal comparisons of streams use these two date columns.  Each result in a stream derives its start and end date from its corresponding row in its table of origin.

For instance, a condition_occurrence result derives its start_date and end_date from the start_date and end_date columns of its row in the clinical codes table.

If a result comes from a table that only has a single date value, the result derives both its start_date and end_date from that single date, e.g. a death result derives both its start_date and end_date from the date column of its row in deaths.

The person stream is a special case.  Person results use the person's date of birth as the start_date and end_date.  This may sound strange, but we will explain below why this makes sense.

### Relative Temporal Operators

When looking at a set of results for a person, perhaps we want to select just the chronologically first or last result.  Or maybe we want to select the 2nd result or 2nd to last result.  Relative temporal operators provide this type of filtering.  Relative temporal operators use a result's start_date to do chronological ordering.

#### occurrence

- Takes a two arguments: the stream to select from and an integer argument
- For the integer argument
    - Positive numbers mean 1st, 2nd, 3rd occurrence in chronological order
        - e.g. 1 => first
        - e.g. 4 => fourth
    - Negative numbers mean 1st, 2nd, 3rd occurrence in reverse chronological order
        - e.g. -1 => last
        - e.g. -4 => fourth from last
    - 0 is undefined?

```ConceptQL
# For each patient, select the Condition that represents the second occurrence of an MI
[
  "occurrence",
  2,
  [
    "icd9",
    "412"
  ]
]
```

#### first

- Operator that is shorthand for writing "occurrence: 1"

```ConceptQL
# For each patient, select the Condition that represents the first occurrence of an MI
[
  "first",
  [
    "icd9",
    "412"
  ]
]
```

#### last

- Operator that is just shorthand for writing "occurrence: -1"

```ConceptQL
# For each patient, select the Condition that represents the last occurrence of an MI
[
  "last",
  [
    "icd9",
    "412"
  ]
]
```

### Date Literals

For situations where we need to represent pre-defined date ranges, we can use "date literal" operators.

#### date_range

- Takes a hash with two elements: { start: \<date-format\>, end: \<date-format\> }
- Creates an inclusive, continuous range of dates defined by a start and end date

#### day

- Takes a single argument: \<date-format\>
- Represents a single day
- Shorthand for creating a date range that starts and ends on the same date
- *Not yet implemented*

#### What is <date-format\>?

Dates follow these formats:

- "YYYY-MM-DD"
    - Four-digit year, two-digit month with leading 0s, two-digit day with leading 0s
- "START"
    - Represents the first date of information available from the data source
- "END"
    - Represents the last date of information available from the data source.

### Temporal Comparison Operators

As described above, each result carries a start and end date, defining its own date range.  It is through these date ranges that we are able to do temporal filtering of streams via temporal operators.

Temporal operators work by comparing a left-hand stream (L) against a right-hand stream (R).  R can be either a set of streams or a pre-defined date range.  Each temporal operator has a comparison operator which defines how it compares dates between L and R.  A temporal operator passes results only from L downstream.  A temporal operator discards all results in the R stream after it makes all comparisons.

The available set of temporal operators comes from the work of Allen's Interval Algebra[^AIA].  Interval Algebra defines 13 distinct temporal relationships, as shown in this handy chart [borrowed from this website](http://people.kmi.open.ac.uk/carlos/174): ![](http://people.kmi.open.ac.uk/carlos/wp-content/uploads/2011/02/Allens-Algebra.png)

Our implementation of this algebra is originally going to be as strict as listed here, meaning that:

- Before/After
    - There must be a minimum 1-day gap between date ranges
- Meets/Met-by
    - Only if the first date range starts/ends a day before the next date range ends/starts
- Started-by/Starts
    - The start dates of the two ranges must be equal and the end dates must not be
- Finished-by/Finishes
    - The end dates of the two ranges must be equal and the start dates must not be
- Contains/During
    - The start/end dates of the two ranges must be different from each other
- Overlaps/Overlapped-by
    - The start date of one range and the end date of the other range must be outside the overlapping range
- Temporally coincides
    - Start dates must be equal, end dates must be equal

Ryan's Sidebar on These Definitions:
> These strict definitions may not be particularly handy or even intuitive.  It seems like contains, starts, finishes, and coincides are all examples of overlapping ranges.  Starts/finishes seem to be examples of one range containing another.  Meets/met-by seem to be special cases of before/after.  But these definitions, if used in their strict sense, are all mutually exclusive.

> We may want to adopt a less strict set of definitions, though their meaning may not be as easily defined as the one provided by Allen's Interval Algebra

When comparing results in L against a date range, results in L continue downstream only if they pass the comparison.

```ConceptQL
# All MIs for the year 2010
[
  "during",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "date_range",
      {
        "start": "2010-01-01",
        "end": "2010-12-31"
      }
    ]
  }
]
```

When comparing results in L against a set of results in R, the temporal operator compares results in stream L against results in stream R on a person-by-person basis.

- If a person has results in L or R stream, but not in both, none of their results continue downstream
- On a per person basis, the temporal operator joins all results in the L stream to all results in the R stream
    - Any results in the L stream that meet the temporal comparison against any results in the R stream continue downstream

```ConceptQL
# All MIs that occurred during a hospitalization
[
  "during",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "hospitalization"
    ]
  }
]
```

#### Edge behaviors

For 11 of the 13 temporal operators, comparison of results is straight-forward.  However, the before/after operators have a slight twist.

Imagine events 1-1-2-1-2-1.  In my mind, three 1's come before a 2 and two 1's come after a 2.  Accordingly:

- When comparing L **before** R, the temporal operator compares L against the **LAST** occurrence of R per person
- When comparing L **after** R, the temporal operator compares L against the **FIRST** occurrence of R per person

If we're looking for events in L that occur before events in R, then any event in L that occurs before the last event in R technically meet the comparison of "before".  The reverse is true for after: all events in L that occur after the first event in R technically occur after R.

```ConceptQL
# All MIs that occurred before a patient's __last__ case of pneumonia (486)
[
  "before",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "icd9",
      "486"
    ]
  }
]
```

If this is not the behavior you desire, use one of the sequence operators to select which event in R should be the one used to do comparison

```ConceptQL
# All MIs that occurred before a patient's __first__ case of pneumonia (486)
[
  "before",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "first",
      [
        "icd9",
        "486"
      ]
    ]
  }
]
```

## Time Windows

There are situations when the date columns associated with a result should have their values shifted forward or backward in time to make a comparison with another set of dates.

### time_window

- Takes 2 arguments
    - First argument is the stream on which to operate
    - Second argument is a hash with two keys: \[:start, :end\] each with a value in the following format:  "(-?\d+\[dmy\])+"
        - Both start and end must be defined, even if you are only adjusting one of the dates
    - Some examples
        - 30d => 30 days
        - 20 => 20 days
        - d => 1 day
        - 1y => 1 year
        - -1m => -1 month
        - 10d3m => 3 months and 10 days
        - -2y10m-3d => -2 years, +10 months, -3 days
    - The start or end value can also be '', '0', or nil
        - This will leave the date unaffected
    - The start or end value can also be the string 'start' or 'end'
        - 'start' represents the start_date for each result
        - 'end' represents the end_date for each result
        - See the example below

```ConceptQL
# All Diagnoses of Pneumonia (ICD-9 486) within 30 days of an MI
[
  "during",
  {
    "left": [
      "icd9",
      "486"
    ],
    "right": [
      "time_window",
      [
        "icd9",
        "412"
      ],
      {
        "start": "-30d",
        "end": "30d"
      }
    ]
  }
]
```

```ConceptQL
# Shift the window for all MIs back by 2 years
[
  "time_window",
  [
    "icd9",
    "412"
  ],
  {
    "start": "-2y",
    "end": "-2y"
  }
]
```

```ConceptQL
# Expand the dates for all MIs to a window ranging from 2 months and 2 days prior to 1 year and 3 days after the MI
[
  "time_window",
  [
    "icd9",
    "412"
  ],
  {
    "start": "-2m-2d",
    "end": "3d1y"
  }
]
```

```ConceptQL
# Collapse all hospitalizations' date ranges down to just the date of admission by leaving start_date unaffected and setting end_date to start_date
[
  "time_window",
  [
    "hospitalization"
  ],
  {
    "start": "",
    "end": "start"
  }
]
```

```ConceptQL
# Nonsensical, but allowed: swap the start_date and end_date for a range
[
  "time_window",
  [
    "icd9",
    "412"
  ],
  {
    "start": "end",
    "end": "start"
  }
]
```

### Temporal Operators and Person Streams

Person streams carry a patient's date of birth in their date columns.  This makes them almost useless when they are part of the L stream of a temporal operator.  But person streams are useful as the R stream.  By ```time_window```ing the patient's date of birth, we can filter based on the patient's age like so:

```ConceptQL
# All MIs that occurred after a male patient's 50th birthday
[
  "after",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "time_window",
      [
        "gender",
        "Male"
      ],
      {
        "start": "50y",
        "end": "50y"
      }
    ]
  }
]
```

## Type Conversion

There are situations where it is appropriate to convert the type of a stream of results into a different type.  In programmer parlance, we say "typecasting" or "casting", which is the terminology we'll use here.  A good analogy and mnemonic for casting is to think of taking a piece of metal, say a candle holder, melting it down, and recasting it into, say, a lamp.  We'll do something similar with streams.  We'll take, for example, a condition_occurrence stream and recast it into a stream of person.

ConceptQL has two casting operators: person and death.  GDM has no visit table to cast to.  To find conditions and procedures that were reported in the same source record, such as the same claim, use the co_reported operator (see Co-reported Events).

### Casting to person

- Useful if we're just checking for the presence of a condition for a person
- E.g. We want to know *if* a person has an old MI, not when an MI or how many MIs occurred

```ConceptQL
# All People Who Had an MI
[
  "person",
  [
    "icd9",
    "412"
  ]
]
```

### Casting to death

- Replaces each result with the death record of the result's person
- A person with no death record yields no results

```ConceptQL
# The Deaths of All People Who Had an MI
[
  "death",
  [
    "icd9",
    "412"
  ]
]
```

### Casting Loses All Original Information

After a result undergoes casting, it loses its original information.  E.g. casting a condition_occurrence to a person loses the condition information and resets the start_date and end_date columns to the person's date of birth.  As a side note, this is actually handy if a person stream's dates have been altered by a time_window operator and you want the original dates later on.  Just cast the stream to person again and it will regain the date of birth.

### Casting as a way to fetch all rows

The casting operator doubles as a way to fetch all rows for a single type.  Provide the casting operator with no upstream operator to get all rows as results:

```ConceptQL
# All death results in the database
[
  "death"
]
```

This comes in handy for situations like these:

```ConceptQL
# All Male patients who died
[
  "person_filter",
  {
    "left": [
      "gender",
      "Male"
    ],
    "right": [
      "death"
    ]
  }
]
```

## Filtering by People

Often we want to filter out a set of results by people.  For instance, say we wanted to find all MIs for all males.  We'd use the person_filter operator for that.  Like the Except operator, it takes a left-hand stream and a right-hand stream.

Unlike the ```except``` operator, the person_filter operator will use all types of all streams in the right-hand side to filter out results in all types of all streams on the left hand side.

```ConceptQL
# All MI Conditions for people who are male
[
  "person_filter",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "gender",
      "Male"
    ]
  }
]
```

But we can get crazier.  The right-hand side doesn't have to be a person stream.  If a non-person stream is used in the right-hand side, the person_filter will cast all right-hand streams to person first and use the union of those streams:

```ConceptQL
# All MI Conditions for people who had an office visit at some point in the data
[
  "person_filter",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "cpt",
      "99214"
    ]
  }
]
```

```ConceptQL
# All MI Conditions for people who had an office visit at some point in the data (an explicit representation of what's happening in the diagram above)
[
  "person_filter",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "person",
      [
        "cpt",
        "99214"
      ]
    ]
  }
]
```

```ConceptQL
# All MI Conditions for people who are Male OR had an office visit at some point in the data
[
  "person_filter",
  {
    "left": [
      "icd9",
      "412"
    ],
    "right": [
      "union",
      [
        "cpt",
        "99214"
      ],
      [
        "gender",
        "Male"
      ]
    ]
  }
]
```

And don't forget the left-hand side can have multiple types of streams:

```ConceptQL
# Yields two streams: a stream of all MI Conditions for people who are Male and a stream of all office visit Procedures for people who are Male
[
  "person_filter",
  {
    "left": [
      "union",
      [
        "icd9",
        "412"
      ],
      [
        "cpt",
        "99214"
      ]
    ],
    "right": [
      "gender",
      "Male"
    ]
  }
]
```

## Sub-algorithms within a Larger Algorithm

If a algorithm is particularly complex, or has a stream of results that are used more than once, it can be helpful to break the algorithm into a set of sub-algorithms.  This can be done using the `label` options and the `recall` operator.

### `label` option

Any ConceptQL operator can be assigned a label.  The label simply provides a way to apply a brief description to an operator, generally, what kind of results the operator is producing.  Any operator that has a label can be accessed via the `recall` operator.

### `recall` operator

- Takes 1 argument
    - The "label" of an operator from which you'd like to pull the exact same set of results

A stream must have a `label` before `recall` can use it.

```ConceptQL
# Save away a stream of results to build the 1 inpatient, 2 outpatient pattern used in claims data algorithms
[
  "first",
  [
    "union",
    [
      "provenance",
      [
        "icd9",
        "412",
        {
          "label": "Heart Attack"
        }
      ],
      "inpatient"
    ],
    [
      "before",
      {
        "left": [
          "provenance",
          [
            "recall",
            "Heart Attack"
          ],
          "outpatient",
          {
            "label": "Outpatient Heart Attack"
          }
        ],
        "right": [
          "time_window",
          [
            "recall",
            "Outpatient Heart Attack"
          ],
          {
            "start": "-30d",
            "end": "0"
          }
        ],
        "label": "Earliest of Two Outpatient Heart Attacks"
      }
    ]
  ]
]
```

ConceptQL also has a `one_in_two_out` operator that implements this pattern in a single operator.

## Algorithms within Algorithms

One of the main motivations behind keeping ConceptQL so flexible is to allow users to build ConceptQL statements from other ConceptQL statements.  This section describes how this feature works.

Say a ConceptQL statement gathers all pneumonia diagnoses (ICD-9 486) and hospital visits (CPT 99232, subsequent hospital care) that were reported in the same source record:

```ConceptQL
# All Pneumonia Diagnoses and Hospital Visits reported in the same source record
[
  "co_reported",
  [
    "icd9",
    "486"
  ],
  [
    "cpt",
    "99232"
  ]
]
```

The "algorithm" operator represents a stored ConceptQL statement in a new statement.  It takes the ID of the stored statement.  ConceptQL reads the stored statement from the `statement` column of the `concepts` table, in the row whose `concept_id` is that ID.  So, assuming that the ID 2031 represents the algorithm defined above, we could gather all the people with those records like this:

```ConceptQL
# All People with a Pneumonia Diagnosis and a Hospital Visit reported in the same source record
[
  "person",
  [
    "algorithm",
    2031
  ]
]
```

ConceptQL replaces the algorithm operator with the stored statement when it reads the statement, so the diagram above shows the stored statement.  The result of nesting one algorithm within another is exactly the same had we taken algorithm operator and replaced it with the ConceptQL statement for the algorithm it represents.

```ConceptQL
# All People with a Pneumonia Diagnosis and a Hospital Visit reported in the same source record (same as above)
[
  "person",
  [
    "co_reported",
    [
      "icd9",
      "486"
    ],
    [
      "cpt",
      "99232"
    ]
  ]
]
```

## Values

A result can carry forward three different types of values:

- value_as_number
    - For values like lab values, counts of occurrence of results, or sums
- value_as_string
    - For values that are text, such as a lab result that is text
- value_as_concept_id
    - For values that are concepts, such as a coded lab result

By default, all value fields are set to NULL, unless an operator is explicitly written to populate one or more of those fields.

There are many operations that can be performed on the value_as\_\* columns and as those operations are implemented, this section will grow.

For now we'll cover some of the general behavior of the value_as_number column and it's associated operators.

### numeric

- Takes 2 arguments
    - A stream
    - And a numeric value

Passing streams through a `numeric` operator changes the number stored in the value column:

```ConceptQL
# All MIs, setting value_as_number to 2
[
  "numeric",
  2,
  [
    "icd9",
    "412"
  ]
]
```

With a `numeric` operator defined, we can use the `sum` operator to sum the values for each patient and type.  This allows us to implement the Charlson comorbidity algorithm:

```ConceptQL
[
  "sum",
  [
    "union",
    [
      "numeric",
      1,
      [
        "person",
        [
          "icd9",
          "412"
        ]
      ]
    ],
    [
      "numeric",
      2,
      [
        "person",
        [
          "icd9",
          "278.02"
        ]
      ]
    ]
  ]
]
```

### Counting

The `count` operator groups identical results and stores the number of results in each group in the value_as_number column.  Two results are identical only when all of their columns match, including criterion_id.  So `count` does not count the events of each person.  Casting a stream to person first does not help, because the cast yields one result for each person.

To count the events of each person, set value_as_number to 1 with `numeric`, and then use `sum`:

```ConceptQL
# Count the number of times each person had pneumonia
[
  "sum",
  [
    "numeric",
    1,
    [
      "icd9",
      "486"
    ]
  ]
]
```

We could do dumb things like count the number of times a row shows up in a union:

```ConceptQL
# All rows with a value of 2 would be rows that were both MI and from an inpatient record
[
  "count",
  [
    "union",
    [
      "icd9",
      "412"
    ],
    [
      "provenance",
      [
        "icd9",
        "412"
      ],
      "inpatient"
    ]
  ]
]
```

#### Numeric Value Comparison

The `numeric_filter` operator takes one stream.  It passes along the results whose value_as_number is in a range, and it drops results whose value_as_number is NULL.  It takes two options, and both are inclusive:

- greater_than_or_equal_to
- less_than_or_equal_to

```ConceptQL
# People with more than 1 MI
[
  "person",
  [
    "numeric_filter",
    [
      "sum",
      [
        "numeric",
        1,
        [
          "icd9",
          "412"
        ]
      ]
    ],
    {
      "greater_than_or_equal_to": 2
    }
  ]
]
```

### numeric as selection operator

Numeric doesn't have to take a stream.  If it doesn't have a stream as an argument, it acts like a selection operator much like date_range.  It yields one person result for each patient, with value_as_number set to its value.

```ConceptQL
# All patients, each with value_as_number set to 1
[
  "numeric",
  1
]
```

#### sum

- Takes a stream of results and does some wild things
    - Groups the results by all of their columns except criterion_id, start_date, end_date, and value_as_number, which puts the results of each person and type in one group when they share a source_value
        - Sums the value_as_number column within that grouping
        - Sets start_date to the earliest start_date in the group
        - Sets the end_date to the most recent end_date in the group
        - Sets criterion_id to 0 since there is no particular single row that the result refers to anymore

## Appendix A - Selection Operators

ConceptQL creates a vocabulary operator for each vocabulary in its vocabulary list (`config/vocabularies.csv`) and in its vocabulary database.  This table lists the most common selection operators.

| Operator Name | Stream Type | Arguments | Returns |
| ---- | ---- | --------- | ------- |
| cpt  | procedure_occurrence | 1 or more CPT codes | All clinical codes that match any of the CPT codes |
| icd9 | condition_occurrence | 1 or more ICD-9-CM diagnosis codes | All clinical codes that match any of the ICD-9 codes |
| icd9_procedure | procedure_occurrence | 1 or more ICD-9-CM procedure codes | All clinical codes that match any of the ICD-9 procedure codes |
| icd10cm | condition_occurrence | 1 or more ICD-10-CM codes | All clinical codes that match any of the ICD-10-CM codes |
| hcpcs  | procedure_occurrence | 1 or more HCPCS codes | All clinical codes that match any of the HCPCS codes |
| loinc | observation | 1 or more LOINC codes | All clinical codes that match any of the LOINC codes |
| ndc | drug_exposure | 1 or more NDC codes | All clinical codes that match any of the NDC codes |
| rxnorm | drug_exposure | 1 or more RxNorm codes | All clinical codes that match any of the RxNorm codes |
| snomed | condition_occurrence | 1 or more SNOMED codes | All clinical codes that match any of the SNOMED codes |
| gender | person | 1 or more of Male, Female, and Unknown | All patients whose gender matches any of the arguments |
| race | person | 1 or more race names or race concept IDs | All patients whose race matches any of the arguments |
| death | death | None | All death records |
| information_periods | observation_period | None | All information periods |
| date_range | person | A start date and an end date | One result for each patient, with the given dates |

## Appendix B - Algorithm Showcase

Here I take some algorithms from [OMOP's Health Outcomes of Interest](http://omop.org/HOI) and turn them into ConceptQL statements to give more examples.  I truncated some of the sets of codes to help ensure the diagrams didn't get too large.

### Acute Kidney Injury - Narrow Definition and diagnositc procedure

- ICD-9 of 584 (584.5 through 584.9)
- AND
    - ICD-9 procedure codes of 39.95 or 54.98 within 60 days after diagnosis
- AND NOT
    - A diagnostic code of chronic dialysis any time before initial diagnosis
        - V45.1, V56.0, V56.31, V56.32, V56.8

```ConceptQL
[
  "during",
  {
    "left": [
      "except",
      {
        "left": [
          "icd9",
          "584.5",
          "584.6",
          "584.7",
          "584.8",
          "584.9"
        ],
        "right": [
          "after",
          {
            "left": [
              "icd9",
              "584.5",
              "584.6",
              "584.7",
              "584.8",
              "584.9"
            ],
            "right": [
              "icd9",
              "V45.1",
              "V56.0",
              "V56.31",
              "V56.32",
              "V56.8"
            ]
          }
        ]
      }
    ],
    "right": [
      "time_window",
      [
        "icd9_procedure",
        "39.95",
        "54.98"
      ],
      {
        "start": "0",
        "end": "60d"
      }
    ]
  }
]
```

### Mortality after Myocardial Infarction #3

- Person Died
- And Occurrence of an acute MI (ICD-9 410.x1, initial episode of care) prior to death
- And either
    - MI diagnosis within 30 days prior to 410
    - MI therapy within 60 days after 410

```ConceptQL
[
  "during",
  {
    "left": [
      "before",
      {
        "left": [
          "icd9",
          "410.01",
          "410.11",
          "410.21",
          "410.31",
          "410.41",
          "410.51",
          "410.61",
          "410.71",
          "410.81",
          "410.91"
        ],
        "right": [
          "death"
        ]
      }
    ],
    "right": [
      "union",
      [
        "time_window",
        [
          "union",
          [
            "cpt",
            "0146T",
            "75898",
            "82554",
            "92980",
            "93010",
            "93233",
            "93508",
            "93540",
            "93545"
          ],
          [
            "icd9_procedure",
            "00.24",
            "36.02",
            "89.53",
            "89.57",
            "89.69"
          ],
          [
            "loinc",
            "10839-9",
            "13969-1",
            "18843-3",
            "2154-3",
            "33204-9",
            "48425-3",
            "49259-5",
            "6597-9",
            "8634-8"
          ]
        ],
        {
          "start": "-30d",
          "end": "0"
        }
      ],
      [
        "time_window",
        [
          "union",
          [
            "cpt",
            "0146T",
            "75898",
            "82554",
            "92980",
            "93010",
            "93233"
          ],
          [
            "icd9_procedure",
            "00.24",
            "36.02",
            "89.53",
            "89.57",
            "89.69"
          ]
        ],
        {
          "start": "",
          "end": "60d"
        }
      ]
    ]
  }
]
```

### GI Ulcer Hospitalization 2 (5000001002)

- Occurrence of GI Ulcer diagnostic code
- Hospitalization at time of diagnostic code
- At least one diagnostic procedure during same hospitalization

GDM has no visit table.  In this statement, co_reported keeps the ulcer diagnoses and the diagnostic procedures that were reported in the same source record.  Then during keeps those that occurred during a hospitalization.  A shared source record is stricter than a shared hospitalization.

```ConceptQL
# GI Ulcer diagnoses and diagnostic procedures reported in the same source record during a hospitalization
[
  "during",
  {
    "left": [
      "co_reported",
      [
        "icd9",
        "531.00",
        "531.40",
        "531.90",
        "532.40",
        "532.90",
        "533.40",
        "533.90",
        "534.40",
        "534.90"
      ],
      [
        "union",
        [
          "cpt",
          "0008T",
          "3142F",
          "43205",
          "43236",
          "76975",
          "91110",
          "91111"
        ],
        [
          "hcpcs",
          "B4081",
          "B4082"
        ],
        [
          "icd9_procedure",
          "42.22",
          "42.23",
          "44.13",
          "45.13",
          "52.21",
          "97.01"
        ],
        [
          "loinc",
          "16125-7",
          "17780-8",
          "40820-3",
          "50320-1",
          "5177-1",
          "7901-2"
        ]
      ]
    ],
    "right": [
      "hospitalization"
    ]
  }
]
```

## Appendix C - Under Development

ConceptQL is not yet fully specified.  These are modifications/enhancements that are under consideration.  These ideas are most likely not completely refined and might actually represent changes that would fundamentally break ConceptQL.

### Todo List

1. Handle costs
    - How do we aggregate?
1. How do we count?
1. How do we handle missing values in streams?
    - For instance, missing DoB on patient?
1. What does it mean to pass a date range as an L stream?
    - I'm thinking we pass through no results
    - Turns out that, as implemented, a date_range is really a person_stream where the start and end dates represent the range (instead of the date of birth) so we're probably OK
1. How do we want to look up standard vocab concepts?
    - I think Marc’s approach is a bit heavy-handed

Some statements maybe very useful and it would be handy to reuse the bulk of the statement, but perhaps vary just a few things about it.  ConceptQL could use variables to represent sub-expressions.  A variable operator would be a place holder to say "some criteria set belongs here".  That variable could be defined in another part of the criteria set and would be used in all places the variable operator appears.  ConceptQL does not have a variable operator.  The `label` option and the `recall` operator reuse a stream within one statement.

### Future Work for Define and Recall

I'd like to make it so if a variable operator is used, but not defined, the algorithm is still valid, but will fail to run until a definition for all missing variables is provided.

But I don't have a good feel for:

- Whether we should have users name the variables, or auto-assign a name?
    - We risk name collisions if a algorithm includes a sub-algorithm with the same variable name
    - Probably need to name space all variables
- How to prompt users to enter values for variables in a concept
    - If we have name-spaced variables and sub-algorithms needing values, how do we show this in a coherent manner to a user?
- We'll need to do a pass through a algorithm to find all variables and prompt a user, then do another pass through the algorithm before attempting to execute it to ensure all variables have values
    - Do we throw an exception if not?
    - Do we require calling programs to invoke a check on the algorithm before generating the query?
- Perhaps slot is a different operator from "define"

### Considerations for Values

I'm considering defaulting each value_as\_\* column to some value.

- numeric => 1
- concept_id => 0
    - Or maybe the concept_id of the main concept_id value from the row?
        - This would be confusing when pulling from the observation table
        - What's the "main" concept_id of a person?
        - Hm.  This feels a bit less like a good idea now
- string
    - source_value?
    - Boy, this one is even harder to default

```ConceptQL
# All MIs, defaulting value_as_number to 1, value_as_concept_id to the concept ID for 412, value_as_string to the source code
[
  "icd9",
  "412"
]
```

### `as` Option for Filter

The filter operator (see Set Operators) keeps left-hand results that also appear in the right-hand stream.  An `as` option could temporarily cast the left-hand and right-hand streams to the type it names, and then keep the left-hand results whose cast results appear on both sides.  That would be handy for keeping procedures that coincide with conditions without fully casting the streams.  With `"as": "person"`, filter would behave like person_filter.  ConceptQL does not have this option.

### AS option for Except

Like the proposed `as` option for filter, add an `as` option to the Except operator.  This would simplify some of the algorithms I've developed.

[^AIA]: J. Allen. Maintaining knowledge about temporal intervals. Communications of the ACM (1983) vol. 26 (11) pp. 832-843
