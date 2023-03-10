# ConceptQL [![Run Tests](https://github.com/outcomesinsights/conceptql/actions/workflows/run_tests.yml/badge.svg)](https://github.com/outcomesinsights/conceptql/actions/workflows/run_tests.yml)

ConceptQL (pronounced concept-Q-L) is a high-level language that allows researchers to unambiguously define their research algorithms.

This gem interprets the ConceptQL language and translates it into SQL queries compatible with [Generalized Data Model (GDM)](https://github.com/outcomesinsights/generalized_data_model#contexts)-structured data.  The ConceptQL "language" is a set of nested arrays and hashes representing search criteria with some set operations and temporal operations to glue those criteria together.

## Further Reading

If you're interested in reading up on ConceptQL, a the specifications document is [available in markdown format](https://github.com/outcomesinsights/conceptql_spec).

## Motivation for ConceptQL

Outcomes Insights has built a vast library of research algorithms and applied those algorithms to large databases of claims data.  Early into building the library, we realized we had to overcome two major issues:

1. Methods sections of research papers commonly use natural language to specify the criteria used to build cohorts from a claims database.
    - Algorithms defined in natural language are often imprecise, open to multiple interpretations, and generally difficult to reproduce.
    - Researchers could benefit from a language that removes the ambiguity of natural language while increasing the reproducibility of their research algorithms.
1. Querying against claims databases is often difficult.
    - Hand-coding algorithms to extract cohorts from datasets is time-consuming, error-prone, and opaque.
    - Researchers could benefit from a language that allows algorithms to be defined at a high-level and then gets translated into the appropriate queries against a database.

We developed ConceptQL to address these two issues.

We have written a tool that can read research algorithms defined in ConceptQL.  The tool can create a diagram for the algorithm which makes it easy to visualize and understand.  The tool can also translate the algorithm into a SQL query which runs against data structured in the [Generalized Data Model (GDM)](https://github.com/outcomesinsights/generalized_data_model).  The purpose of the GDM is to standardize the format and content of observational data, so standardized applications, tools and methods can be applied to them.

For instance, using ConceptQL we can take a statement that looks like this:

```JSON
[ "icd9", "412" ]
```

And generate a diagram that looks like this:

![](doc/diagram_0.png)

And generate SQL that looks like this:

```SQL
SELECT *
FROM gdm_data.clinical_codes AS cc
WHERE cc.clinical_code_concept_id IN (
  SELECT id
  FROM concepts
  WHERE vocabulary_id = 'ICD9CM'
    AND concept_code = '412'
)
```

As stated above, one of the goals of ConceptQL is to make it easy to assemble fairly complex queries without having to roll up our sleeves and write raw SQL.  We believe ConceptQL will help researchers define, hone, and share their research algorithms.

## Requirements

ConceptQL works best with data stored in the [GDM](https://github.com/outcomesinsights/generalized_data_model#contexts) using [PostgreSQL](http://www.postgresql.org/) as the RDBMS engine.  It has been tested under [Ubuntu Linux](http://www.ubuntu.com/).  The interpreter is written in Ruby and theoretically should be platform independent, but your mileage may vary.

Specifically, ConceptQL is tested against:

- Ruby 3.2
- PostgresQL 14

## Thanks

- [Outcomes Insights, Inc.](http://outins.com)
    - Many thanks for allowing me to release a portion of my work as Open Source Software!
- [OHDSI](http://www.ohdsi.org/)
    - Thank you for providing the original inspiration for ConceptQL.
- [Jeremy Evans](http://code.jeremyevans.net/)
    - Thank you for the great contributions, ideas, and commits.
