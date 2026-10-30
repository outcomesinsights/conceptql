# ConceptQL Specification

ConceptQL (pronounced concept-Q-L) is a high-level language that allows researchers to unambiguously define their research algorithms.

## Motivation for ConceptQL

Outcomes Insights intends to build a vast library of research algorithms and apply those algorithms to large databases of claims data. Early into building the library, we realized we had to overcome two major issues:

1. Methods sections of research papers commonly use natural language to specify the criteria used to build cohorts from a claims database.
   - Algorithms defined in natural language are often imprecise, open to multiple interpretations, and generally difficult to reproduce.
   - Researchers could benefit from a language that removes the ambiguity of natural language while increasing the reproducibility of their research algorithms.
2. Querying against claims databases is often difficult.
   - Hand-coding algorithms to extract cohorts from datasets is time-consuming, error-prone, and opaque.
   - Researchers could benefit from a language that allows algorithms to be defined at a high-level and then gets translated into the appropriate queries against a database.

We developed ConceptQL to address these two issues.

We are writing a tool that can read research algorithms defined in ConceptQL. The tool can create a diagram for the algorithm which makes it easy to visualize and understand. The tool can also translate the algorithm into a SQL query which runs against data structured in the Generalized Data Model (GDM). GDM standardizes the format of observational healthcare data, such as claims, so that the same algorithm can run against many data sources.

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

ConceptQL supports two variants of GDM. The data model `gdm` reads clinical codes from clinical_codes. The data model `gdm_wide` reads them from observations, a wide table that holds the same rows as clinical_codes with the columns of their contexts and collections joined on. ConceptQL looks up codes, such as ICD-9 412, in a vocabulary database to find their concept IDs.

For instance, using ConceptQL we can take a statement that looks like this:

```YAML
- icd9
- '412'
```

And generate a diagram that looks like this:

```YAML
---
- icd9
- '412'

```

![](spec/f6b4fc31703cfb6327bbbd4614af8bb72da6d39fa3d53ada63a70157f2fad80e.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |

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

As stated above, one of the goals of ConceptQL is to make it easy to assemble fairly complex queries without having to roll up our sleeves and write raw SQL. To accommodate this complexity, ConceptQL itself has some complexities of its own. That said, we believe ConceptQL will help researchers define, hone, and share their research algorithms.

## ConceptQL Overview

### What ConceptQL Looks Like

I find seeing examples to be the quickest way to get a sense of a language. Here is a trivial example to whet your appetite. The example is in YAML, but could just as easily be in JSON or any other markup language capable of representing nested sets of heterogeneous arrays and hashes. In fact, the ConceptQL "language" is a just set of nested hashes and arrays representing search criteria and some set operations and temporal operations to glue those criteria together.

```YAML
# Example 1: A simple example in YAML
# This is just a simple array: the name of an operator, icd9, followed by its argument, 412
# This example will search the clinical codes for all conditions that match the ICD-9 code 412.
---
- icd9
- '412'
```

### ConceptQL Diagrams

Reading ConceptQL in YAML or JSON seems hard to me. I prefer to explore ConceptQL using directed graphs. For instance, the diagram for the simple example listed in YAML above is:

```YAML
---
- icd9
- '412'

```

![All Conditions Matching MI](spec/f6b4fc31703cfb6327bbbd4614af8bb72da6d39fa3d53ada63a70157f2fad80e.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |

Each oval depicts a "operator", or rather, a ConceptQL expression. An arrow between a pair of operators indicates that the results from the operator on the tail of the arrow pass on to the operator at the head of the arrow. A simple example should help here:

```YAML
---
- first
- - cpt
  - '99214'

```

![First Office Visit Per Patient](spec/39d6a8eb71cae51b1d6937c97134e51f04fd47c54535ff0915fe6a8b4f197fb2.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 2         | 58127        | observations    | procedure_occurrence | 2009-07-03 | 2009-07-03 | 99214        |
| 5         | 38313        | observations    | procedure_occurrence | 2008-12-14 | 2008-12-14 | 99214        |
| 6         | 48992        | observations    | procedure_occurrence | 2009-09-12 | 2009-09-12 | 99214        |
| 7         | 63797        | observations    | procedure_occurrence | 2008-08-13 | 2008-08-13 | 99214        |
| 8         | 55871        | observations    | procedure_occurrence | 2008-02-27 | 2008-02-27 | 99214        |
| 9         | 45498        | observations    | procedure_occurrence | 2009-09-11 | 2009-09-11 | 99214        |
| 10        | 48752        | observations    | procedure_occurrence | 2009-05-09 | 2009-05-09 | 99214        |
| 11        | 73107        | observations    | procedure_occurrence | 2008-06-17 | 2008-06-17 | 99214        |
| 12        | 71635        | observations    | procedure_occurrence | 2008-02-11 | 2008-02-11 | 99214        |
| 13        | 74458        | observations    | procedure_occurrence | 2008-01-24 | 2008-01-24 | 99214        |

The diagram above reads "get all procedures that match the CPT 99214 (Office Visit) and then filter them down to the first occurrence for each person". The diagram is much more terse than that and to accurately read the diagram, you need a lot of implicit knowledge about how each operator operates. Fortunately, this document will (hopefully) impart that knowledge to you.

Please note that all of my diagrams end with an arrow pointing at nothing. You'll see why soon.

### Think of Results as a Stream

I draw my ConceptQL diagrams with leaf operators at the top and the "trunk" operators at the bottom. I like to think of the results of a ConceptQL statement as a flowing stream of data. The leaf operators, or operators that gather results out of the database, act like tributaries. The results flow downwards and either join with other results, or filter out other results until the streams emerge at the bottom of the diagram. Think of each arrow as a stream of results, flowing down through one operator to the next.

The trailing arrow in the diagrams serves as a reminder that ConceptQL yields a stream of results.

### Streams have Types

You might have noticed that the operators and edges in the diagrams often have a color. That color represents what "type" of stream the operator or edge represents. A stream's type is the domain of its results. Each result reports its type in the criterion_domain column. These are the most common types, with their colors in the diagrams:

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

Each stream has a point of origin: the selection operator that pulled its results out of the database. Based on that origin, each stream will have a particular type. The type does not always match the table. Most results come from the clinical codes table, and a vocabulary operator gives its results the domain of its vocabulary. For example, `icd9` yields condition_occurrence results and `cpt` yields procedure_occurrence results, but both read the same table. Results from patients are person results, results from deaths are death results, and results from information_periods are observation_period results. The stream carries this type information as it moves through each operator. When certain operators, particularly set and temporal operators, need to perform filtering, they can use this type information to determine how to best filter a stream. There will be much more discussion about types woven throughout this document. For now, it is sufficient to know that each stream has a type.

You'll also notice that the trailing arrow(s) at the end of the diagrams indicate which types of streams are ultimately passed on at the end of a ConceptQL statement.

### What *are* Streams Really?

Though I think that a "stream" is a helpful abstraction when thinking in ConceptQL, on a few occasions we need to know what's going on under the hood.

Every table in GDM has a surrogate key column, id. When we execute a ConceptQL statement, the "streams" that are generated by the statement are just sets of these IDs for rows that matched the ConceptQL criteria. Each result carries the ID of its row in the criterion_id column and the name of its table of origin in the criterion_table column. So each stream is just a set of IDs that point back to some rows in the GDM tables. The "type" of a stream is the criterion_domain of its results.

So when we execute this ConceptQL statement, the resulting "stream" is all the patient IDs for all male patients in the database:

```YAML
---
- gender
- Male

```

![All Male Patients](spec/c82077b9455d0f9abc2c45ee1a298e38b99c9ce9cd685f65d87b376d7718d7ad.png)

| person_id | criterion_id | criterion_table | criterion_domain | start_date | end_date   | source_value     |
| --------- | ------------ | --------------- | ---------------- | ---------- | ---------- | ---------------- |
| 1         | 1            | patients        | person           | 1923-05-01 | 1923-05-01 | 00013D2EFD8E45D1 |
| 2         | 2            | patients        | person           | 1943-01-01 | 1943-01-01 | 00016F745862898F |
| 4         | 4            | patients        | person           | 1941-06-01 | 1941-06-01 | 00021CA6FF03E670 |
| 5         | 5            | patients        | person           | 1936-08-01 | 1936-08-01 | 00024B3D2352D2D0 |
| 6         | 6            | patients        | person           | 1943-10-01 | 1943-10-01 | 0002DAE1C81CC70D |
| 7         | 7            | patients        | person           | 1922-07-01 | 1922-07-01 | 0002F28CE057345B |
| 8         | 8            | patients        | person           | 1935-09-01 | 1935-09-01 | 000308435E3E5B76 |
| 12        | 12           | patients        | person           | 1929-06-01 | 1929-06-01 | 00048EF1F4791C68 |
| 14        | 14           | patients        | person           | 1934-05-01 | 1934-05-01 | 00052705243EA128 |
| 16        | 16           | patients        | person           | 1934-01-01 | 1934-01-01 | 0007E57CC13CE880 |

When we execute this ConceptQL statement, the resulting "stream" is the IDs of all clinical codes that match ICD-9 486 (pneumonia), with the type condition_occurrence:

```YAML
---
- icd9
- '486'

```

![All Condition Occurrences that match ICD-9 486](spec/346fab7e13a927b7e8b42795ef1a9da5af9ab9140d3415a7a9dfeab4af44c1d9.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 14        | 1727         | observations    | condition_occurrence | 2008-09-12 | 2008-09-12 | 486          |
| 14        | 38866        | observations    | condition_occurrence | 2009-04-05 | 2009-04-05 | 486          |
| 17        | 31480        | observations    | condition_occurrence | 2009-05-21 | 2009-05-21 | 486          |
| 19        | 57559        | observations    | condition_occurrence | 2008-02-02 | 2008-02-03 | 486          |
| 23        | 28373        | observations    | condition_occurrence | 2009-08-18 | 2009-08-18 | 486          |
| 23        | 40349        | observations    | condition_occurrence | 2009-12-20 | 2009-12-20 | 486          |
| 23        | 35166        | observations    | condition_occurrence | 2010-02-17 | 2010-02-17 | 486          |
| 25        | 79304        | observations    | condition_occurrence | 2009-07-08 | 2009-07-08 | 486          |
| 27        | 86462        | observations    | condition_occurrence | 2010-09-30 | 2010-09-30 | 486          |
| 28        | 42706        | observations    | condition_occurrence | 2009-09-12 | 2009-09-12 | 486          |

Generally, I find it helpful to just think of those queries generating a "stream of people" or a "stream of conditions" and not worry about the table of origin or the fact that they are just IDs.

When a ConceptQL statement is executed, it yields a final set of streams that are just all the IDs that passed through all the criteria. What is done with that set of IDs is up to the user who assembled the ConceptQL statement. If a user gathers all 486 Conditions, they will end up with a set of clinical code IDs. They could take those IDs and do all sorts of things like:

- Gather the first and last date of occurrence per person
- Count the number of occurrences per person
- Count number of persons with the condition
- Count the total number of occurrences for the entire population

This kind of aggregation and analysis is beyond the scope of ConceptQL. ConceptQL will get you the IDs of the rows you're interested in, its up to other parts of the calling system to determine what you do with them.

## Selection Operators

Selection operators are the parts of a ConceptQL query that search for specific values within the GDM data, e.g. searching the clinical codes for a diagnosis of an old myocardial infarction (ICD-9 412) is a selection. Selection operators are always leaf operators.

There are _many_ selection operators. A list of currently implemented operators is available in Appendix A.

## All Other Operators i.e. Mutation Operators

Virtually all other operators add, remove, filter, or otherwise alter streams of results. They are discussed in this section.

## Set Operators

Because streams represent sets of results, its makes sense to include a operators that operate on sets. ConceptQL has three of them: union, filter, and except. It has no intersect operator and no complement operator.

### Union

- Takes any number of upstream operators and aggregates their streams
  - Unions together streams with identical types
    - Think of streams with the same type flowing together into a single stream
    - Union does not remove duplicates: a result that arrives from two upstream operators can appear twice
  - Streams with the different types flow along together concurrently without interacting
    - It does not make sense to union, say, condition_occurrence results with procedure_occurrence results, so streams with different types won't mingle together, but will continue to flow downstream in parallel

```YAML
---
- union
- - icd9
  - '412'
- - icd9
  - '486'

```

![Two streams of the same type (condition_occurrence) joined into a single stream](spec/79939bbb392a2152f20243f018abe44b681393ea0412e06b282dcaa4647476e1.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 14        | 1727         | observations    | condition_occurrence | 2008-09-12 | 2008-09-12 | 486          |
| 14        | 38866        | observations    | condition_occurrence | 2009-04-05 | 2009-04-05 | 486          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 17        | 31480        | observations    | condition_occurrence | 2009-05-21 | 2009-05-21 | 486          |
| 19        | 57559        | observations    | condition_occurrence | 2008-02-02 | 2008-02-03 | 486          |
| 23        | 28373        | observations    | condition_occurrence | 2009-08-18 | 2009-08-18 | 486          |
| 23        | 40349        | observations    | condition_occurrence | 2009-12-20 | 2009-12-20 | 486          |
| 23        | 35166        | observations    | condition_occurrence | 2010-02-17 | 2010-02-17 | 486          |

```YAML
---
- union
- - union
  - - icd9
    - '412'
  - - icd9
    - '486'
- - cpt
  - '99231'

```

![Two streams of the same type (condition_occurrence) joined into a single stream, then a different stream (procedure_occurrence) flows concurrently](spec/4e59dcff780ca34a7e99631e5ad063c11dc7bfe19b14050523cb4f58387b5b81.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 2         | 92691        | observations    | procedure_occurrence | 2008-10-20 | 2008-10-20 | 99231        |
| 7         | 72498        | observations    | procedure_occurrence | 2009-12-24 | 2010-01-02 | 99231        |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 13        | 65589        | observations    | procedure_occurrence | 2008-12-14 | 2008-12-14 | 99231        |
| 14        | 1727         | observations    | condition_occurrence | 2008-09-12 | 2008-09-12 | 486          |
| 14        | 38866        | observations    | condition_occurrence | 2009-04-05 | 2009-04-05 | 486          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 17        | 31480        | observations    | condition_occurrence | 2009-05-21 | 2009-05-21 | 486          |
| 17        | 53417        | observations    | procedure_occurrence | 2008-04-05 | 2008-04-05 | 99231        |

```YAML
---
- union
- - icd9
  - '412'
- - icd9
  - '486'
- - cpt
  - '99231'

```

![Two streams of the same type (condition_occurrence) joined into a single stream, along with a different stream (procedure_occurrence) flows concurrently (same as above example)](spec/5f87dd446147760f348e0e72e1abb72b8be1966e147951cff87e846b87f2d7f7.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 2         | 92691        | observations    | procedure_occurrence | 2008-10-20 | 2008-10-20 | 99231        |
| 7         | 72498        | observations    | procedure_occurrence | 2009-12-24 | 2010-01-02 | 99231        |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 13        | 65589        | observations    | procedure_occurrence | 2008-12-14 | 2008-12-14 | 99231        |
| 14        | 1727         | observations    | condition_occurrence | 2008-09-12 | 2008-09-12 | 486          |
| 14        | 38866        | observations    | condition_occurrence | 2009-04-05 | 2009-04-05 | 486          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 17        | 31480        | observations    | condition_occurrence | 2009-05-21 | 2009-05-21 | 486          |
| 17        | 53417        | observations    | procedure_occurrence | 2008-04-05 | 2008-04-05 | 99231        |

### Filter

This operator takes two sets of incoming streams, a left-hand stream and a right-hand stream. It passes along each left-hand result that also appears in the right-hand stream. Two results are the same when they have the same person_id, criterion_id, criterion_domain, start_date, and end_date. The operator discards all results in the right-hand stream. Use filter to keep only the results that two streams have in common, as an intersection would.

```YAML
---
- filter
- :left:
  - provenance
  - - icd9
    - '412'
  - inpatient
  :right:
  - during
  - :left:
    - icd9
    - '412'
    :right:
    - date_range
    - :start: '2009-01-01'
      :end: '2009-12-31'

```

![All MI Conditions from inpatient records that also occurred in 2009](spec/5180287351cc692b438dc0b13d0fc5d7ef068c716429ecea6a81f18443fe63e0.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |
| 88        | 1572         | observations    | condition_occurrence | 2009-01-03 | 2009-01-09 | 412          |
| 161       | 963          | observations    | condition_occurrence | 2009-10-25 | 2009-10-29 | 412          |
| 177       | 507          | observations    | condition_occurrence | 2009-06-13 | 2009-06-16 | 412          |

The `provenance` operator in this example passes along the results that come from a given kind of source record, here inpatient records.

### Except

This operator takes two sets of incoming streams, a left-hand stream and a right-hand stream. The operator removes any results in the left-hand stream if they appear in the right-hand stream. Two results are the same when they have the same criterion_id, criterion_table, start_date, and end_date. The operator passes only results for the left-hand stream downstream. The operator discards all results in the right-hand stream. For example:

```YAML
---
- except
- :left:
  - icd9
  - '412'
  :right:
  - provenance
  - - icd9
    - '412'
  - inpatient

```

![All Conditions that are MI unless they come from inpatient records](spec/4daefcd16621b00dc32e8e9e14bca04025f2e37539b319b22175bb8d80452a8a.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 88        | 73803        | observations    | condition_occurrence | 2009-05-30 | 2009-05-30 | 412          |
| 90        | 33940        | observations    | condition_occurrence | 2010-05-26 | 2010-05-26 | 412          |

A result in one stream cannot match a result of a different type, so if the left-hand stream has no types that match the right-hand stream, the left-hand stream passes through unaffected:

```YAML
---
- except
- :left:
  - icd9
  - '412'
  :right:
  - cpt
  - '99214'

```

![All Conditions that are MI](spec/253845fe6162621af407ebd110296ff4f6d8a3f23ec75dfb4ea8cda30be71262.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |

And just to show how multiple streams behave:

```YAML
---
- except
- :left:
  - union
  - - icd9
    - '412'
  - - gender
    - Male
  - - cpt
    - '99214'
  :right:
  - union
  - - provenance
    - - icd9
      - '412'
    - inpatient
  - - race
    - White

```

![Passes three streams downstream: a stream of Conditions that are MI but not from inpatient records, a stream of People that are Male but not White, and a stream of Procedures that are office visits (this stream is completely unaffected by the right hand stream)](spec/0e33b527af36923e0d4f9ccca73bcffcc5274cf5bf652a9bed71427b4e616bf5.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value     |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ---------------- |
| 2         | 58127        | observations    | procedure_occurrence | 2009-07-03 | 2009-07-03 | 99214            |
| 2         | 83339        | observations    | procedure_occurrence | 2009-12-02 | 2009-12-02 | 99214            |
| 4         | 4            | patients        | person               | 1941-06-01 | 1941-06-01 | 00021CA6FF03E670 |
| 5         | 38313        | observations    | procedure_occurrence | 2008-12-14 | 2008-12-14 | 99214            |
| 5         | 76788        | observations    | procedure_occurrence | 2009-07-04 | 2009-07-04 | 99214            |
| 5         | 63847        | observations    | procedure_occurrence | 2009-12-21 | 2009-12-21 | 99214            |
| 6         | 6            | patients        | person               | 1943-10-01 | 1943-10-01 | 0002DAE1C81CC70D |
| 6         | 48992        | observations    | procedure_occurrence | 2009-09-12 | 2009-09-12 | 99214            |
| 6         | 76651        | observations    | procedure_occurrence | 2010-02-23 | 2010-02-23 | 99214            |
| 7         | 63797        | observations    | procedure_occurrence | 2008-08-13 | 2008-08-13 | 99214            |

### Discussion about Set Operators

#### Union Operators

##### Q. Why should we allow two different types of streams to continue downstream concurrently?

- This feature lets us do interesting things, like find the first occurrence of either an MI or Death as in the example below
  - Throw in a few more criteria and you could find the first occurrence of all censor events for each patient

```YAML
---
- first
- - union
  - - icd9
    - '412'
  - - death

```

![First occurrence of either MI or Death for each patient](spec/3bf7022e9a06d0b25d7e66f30508c7ac68453b51bbede666c94d7988f681bcad.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 16        | 1            | deaths          | death                | 2010-12-01 | 2010-12-01 |              |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 26        | 2            | deaths          | death                | 2009-07-01 | 2009-07-01 |              |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 65        | 3            | deaths          | death                | 2009-01-01 | 2009-01-01 |              |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |

## Co-reported Events

### co_reported

`co_reported` passes along the events of its upstream streams that were reported in the same source record, for example on the same claim. The source record is the event's context (`context_id`).

A source record is kept only if every upstream stream has at least one event in it. If any one upstream has no event in a record, `co_reported` drops the events of **all** streams in that record. The drop is silent: the operator gives no warning and does not report how many records it removed.

For example, a claim with a diabetes diagnosis and no office-visit procedure contributes nothing to the statement below, not even its diagnosis. In the test data, ICD-9 250.00 has 1,036 events and CPT 99214 has 1,073 events, but only 49 records have both, so `co_reported` returns 98 events.

```YAML
---
- co_reported
- - icd9
  - '250.00'
- - cpt
  - '99214'

```

![Yields the diabetes diagnoses and the office-visit procedures that were reported in the same source record](spec/dfc63bee1d9f447450c764cc505def315209de4c752ce49f4cb3779dd28b1001.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 25        | 93217        | observations    | condition_occurrence | 2008-09-18 | 2008-09-18 | 25000        |
| 25        | 93220        | observations    | procedure_occurrence | 2008-09-18 | 2008-09-18 | 99214        |
| 31        | 87695        | observations    | condition_occurrence | 2008-06-17 | 2008-06-17 | 25000        |
| 31        | 87696        | observations    | procedure_occurrence | 2008-06-17 | 2008-06-17 | 99214        |
| 40        | 81973        | observations    | condition_occurrence | 2009-05-01 | 2009-05-01 | 25000        |
| 40        | 81993        | observations    | procedure_occurrence | 2009-05-01 | 2009-05-01 | 99214        |
| 44        | 44702        | observations    | condition_occurrence | 2008-01-10 | 2008-01-10 | 25000        |
| 44        | 44715        | observations    | procedure_occurrence | 2008-01-10 | 2008-01-10 | 99214        |
| 58        | 35093        | observations    | condition_occurrence | 2009-06-15 | 2009-06-15 | 25000        |
| 58        | 35095        | observations    | procedure_occurrence | 2009-06-15 | 2009-06-15 | 99214        |

## Time-oriented Operators

All results in a stream carry a start_date and end_date with them. All temporal comparisons of streams use these two date columns. Each result in a stream derives its start and end date from its corresponding row in its table of origin.

For instance, a condition_occurrence result derives its start_date and end_date from the start_date and end_date columns of its row in the clinical codes table.

If a result comes from a table that only has a single date value, the result derives both its start_date and end_date from that single date, e.g. a death result derives both its start_date and end_date from the date column of its row in deaths.

The person stream is a special case. Person results use the person's date of birth as the start_date and end_date. This may sound strange, but we will explain below why this makes sense.

### Relative Temporal Operators

When looking at a set of results for a person, perhaps we want to select just the chronologically first or last result. Or maybe we want to select the 2nd result or 2nd to last result. Relative temporal operators provide this type of filtering. Relative temporal operators use a result's start_date to do chronological ordering.

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

```YAML
---
- occurrence
- 2
- - icd9
  - '412'

```

![For each patient, select the Condition that represents the second occurrence of an MI](spec/267385650ec29b77f30e5da3d7103c5ce6982947722d939dfc3ea8e5d030ce59.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 88        | 73803        | observations    | condition_occurrence | 2009-05-30 | 2009-05-30 | 412          |
| 152       | 84298        | observations    | condition_occurrence | 2010-11-22 | 2010-11-22 | 412          |
| 177       | 507          | observations    | condition_occurrence | 2009-06-13 | 2009-06-16 | 412          |
| 187       | 87583        | observations    | condition_occurrence | 2010-12-26 | 2010-12-26 | 412          |
| 212       | 34052        | observations    | condition_occurrence | 2009-10-07 | 2009-10-07 | 412          |
| 213       | 15005        | observations    | condition_occurrence | 2010-02-07 | 2010-02-07 | 412          |
| 214       | 83257        | observations    | condition_occurrence | 2009-11-12 | 2009-11-12 | 412          |
| 220       | 20660        | observations    | condition_occurrence | 2009-10-31 | 2009-10-31 | 412          |
| 223       | 39893        | observations    | condition_occurrence | 2008-10-31 | 2008-10-31 | 412          |

#### first

- Operator that is shorthand for writing "occurrence: 1"

```YAML
---
- first
- - icd9
  - '412'

```

![For each patient, select the Condition that represents the first occurrence of an MI](spec/04491942fcbd741982514f9eb12aeecf3d54b5b69a2b50c8331f7700169d5521.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |
| 88        | 1572         | observations    | condition_occurrence | 2009-01-03 | 2009-01-09 | 412          |

#### last

- Operator that is just shorthand for writing "occurrence: -1"

```YAML
---
- last
- - icd9
  - '412'

```

![For each patient, select the Condition that represents the last occurrence of an MI](spec/ebacbd092e3d1a3c7b745a381e51e8ff9d63a21db23a16940193e18e57bc866f.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |
| 88        | 73803        | observations    | condition_occurrence | 2009-05-30 | 2009-05-30 | 412          |

### Date Literals

For situations where we need to represent pre-defined date ranges, we can use "date literal" operators.

#### date_range

- Takes a hash with two elements: { start: \<date-format>, end: \<date-format> }
- Creates an inclusive, continuous range of dates defined by a start and end date

#### day

- Takes a single argument: \<date-format>
- Represents a single day
- Shorthand for creating a date range that starts and ends on the same date
- *Not yet implemented*

#### What is \<date-format>?

Dates follow these formats:

- "YYYY-MM-DD"
  - Four-digit year, two-digit month with leading 0s, two-digit day with leading 0s
- "START"
  - Represents the first date of information available from the data source
- "END"
  - Represents the last date of information available from the data source.

### Temporal Comparison Operators

As described above, each result carries a start and end date, defining its own date range. It is through these date ranges that we are able to do temporal filtering of streams via temporal operators.

Temporal operators work by comparing a left-hand stream (L) against a right-hand stream (R). R can be either a set of streams or a pre-defined date range. Each temporal operator has a comparison operator which defines how it compares dates between L and R. A temporal operator passes results only from L downstream. A temporal operator discards all results in the R stream after it makes all comparisons.

The available set of temporal operators comes from the work of Allen's Interval Algebra[^AIA]. Interval Algebra defines 13 distinct temporal relationships, as shown in this handy chart [borrowed from this website](http://people.kmi.open.ac.uk/carlos/174): ![](http://people.kmi.open.ac.uk/carlos/wp-content/uploads/2011/02/Allens-Algebra.png)

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

> These strict definitions may not be particularly handy or even intuitive. It seems like contains, starts, finishes, and coincides are all examples of overlapping ranges. Starts/finishes seem to be examples of one range containing another. Meets/met-by seem to be special cases of before/after. But these definitions, if used in their strict sense, are all mutually exclusive.

> We may want to adopt a less strict set of definitions, though their meaning may not be as easily defined as the one provided by Allen's Interval Algebra

When comparing results in L against a date range, results in L continue downstream only if they pass the comparison.

```YAML
---
- during
- :left:
  - icd9
  - '412'
  :right:
  - date_range
  - :start: '2010-01-01'
    :end: '2010-12-31'

```

![All MIs for the year 2010](spec/ba90ef705f7be91c53c5eb4a81a439fa0f7c48532214bd3db3cc5c069160543e.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 90        | 33940        | observations    | condition_occurrence | 2010-05-26 | 2010-05-26 | 412          |
| 109       | 89334        | observations    | condition_occurrence | 2010-07-06 | 2010-07-06 | 412          |
| 110       | 62592        | observations    | condition_occurrence | 2010-06-27 | 2010-06-27 | 412          |
| 152       | 84298        | observations    | condition_occurrence | 2010-11-22 | 2010-11-22 | 412          |
| 187       | 87583        | observations    | condition_occurrence | 2010-12-26 | 2010-12-26 | 412          |
| 213       | 15005        | observations    | condition_occurrence | 2010-02-07 | 2010-02-07 | 412          |
| 217       | 56467        | observations    | condition_occurrence | 2010-06-22 | 2010-06-23 | 412          |
| 239       | 49718        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |

When comparing results in L against a set of results in R, the temporal operator compares results in stream L against results in stream R on a person-by-person basis.

- If a person has results in L or R stream, but not in both, none of their results continue downstream
- On a per person basis, the temporal operator joins all results in the L stream to all results in the R stream
  - Any results in the L stream that meet the temporal comparison against any results in the R stream continue downstream

```YAML
---
- during
- :left:
  - icd9
  - '412'
  :right:
  - hospitalization

```

![All MIs that occurred during a hospitalization](spec/9524ac806e9ac1dd97132bc6b66a793536b9d8fa31d7ded9f54fba018e6288aa.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |
| 88        | 1572         | observations    | condition_occurrence | 2009-01-03 | 2009-01-09 | 412          |
| 131       | 172          | observations    | condition_occurrence | 2008-03-22 | 2008-03-23 | 412          |
| 161       | 963          | observations    | condition_occurrence | 2009-10-25 | 2009-10-29 | 412          |
| 177       | 507          | observations    | condition_occurrence | 2009-06-13 | 2009-06-16 | 412          |
| 230       | 523          | observations    | condition_occurrence | 2008-03-14 | 2008-03-21 | 412          |

#### Edge behaviors

For 11 of the 13 temporal operators, comparison of results is straight-forward. However, the before/after operators have a slight twist.

Imagine events 1-1-2-1-2-1. In my mind, three 1's come before a 2 and two 1's come after a 2. Accordingly:

- When comparing L **before** R, the temporal operator compares L against the **LAST** occurrence of R per person
- When comparing L **after** R, the temporal operator compares L against the **FIRST** occurrence of R per person

If we're looking for events in L that occur before events in R, then any event in L that occurs before the last event in R technically meet the comparison of "before". The reverse is true for after: all events in L that occur after the first event in R technically occur after R.

```YAML
---
- before
- :left:
  - icd9
  - '412'
  :right:
  - icd9
  - '486'

```

![All MIs that occurred before a patient's last case of pneumonia (486)](spec/fc3b7c03816cc84fd92931b2cd0eb279e3fba5851e1ce15d4f084a1a3f04feba.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 96        | 20748        | observations    | condition_occurrence | 2008-09-21 | 2008-09-24 | 412          |
| 109       | 89334        | observations    | condition_occurrence | 2010-07-06 | 2010-07-06 | 412          |
| 131       | 172          | observations    | condition_occurrence | 2008-03-22 | 2008-03-23 | 412          |
| 149       | 28518        | observations    | condition_occurrence | 2008-04-07 | 2008-04-07 | 412          |
| 152       | 82988        | observations    | condition_occurrence | 2008-08-16 | 2008-08-16 | 412          |

If this is not the behavior you desire, use one of the sequence operators to select which event in R should be the one used to do comparison

```YAML
---
- before
- :left:
  - icd9
  - '412'
  :right:
  - first
  - - icd9
    - '486'

```

![All MIs that occurred before a patient's first case of pneumonia (486)](spec/bd129d7a0fc5b3ee6610f990e4d8a6c604825e11ed04123c202595a08f917438.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 96        | 20748        | observations    | condition_occurrence | 2008-09-21 | 2008-09-24 | 412          |
| 109       | 89334        | observations    | condition_occurrence | 2010-07-06 | 2010-07-06 | 412          |
| 131       | 172          | observations    | condition_occurrence | 2008-03-22 | 2008-03-23 | 412          |
| 149       | 28518        | observations    | condition_occurrence | 2008-04-07 | 2008-04-07 | 412          |
| 152       | 82988        | observations    | condition_occurrence | 2008-08-16 | 2008-08-16 | 412          |
| 213       | 55557        | observations    | condition_occurrence | 2009-06-07 | 2009-06-07 | 412          |

## Time Windows

There are situations when the date columns associated with a result should have their values shifted forward or backward in time to make a comparison with another set of dates.

### time_window

- Takes 2 arguments
  - First argument is the stream on which to operate
  - Second argument is a hash with two keys: [:start, :end] each with a value in the following format: "(-?\\d+[dmy])+"
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

```YAML
---
- during
- :left:
  - icd9
  - '486'
  :right:
  - time_window
  - - icd9
    - '412'
  - :start: "-30d"
    :end: 30d

```

![All Diagnoses of Pneumonia (ICD-9 486) within 30 days of an MI](spec/c01589dc9f64d7ad8ef808d7471d19abec29f06771b06da7f3f884f3ea2fdc43.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 17        | 31480        | observations    | condition_occurrence | 2009-05-21 | 2009-05-21 | 486          |
| 38        | 47462        | observations    | condition_occurrence | 2010-02-24 | 2010-02-24 | 486          |
| 38        | 47463        | observations    | condition_occurrence | 2010-02-24 | 2010-02-24 | 486          |
| 38        | 47464        | observations    | condition_occurrence | 2010-02-24 | 2010-02-24 | 486          |
| 60        | 988          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 486          |
| 77        | 62783        | observations    | condition_occurrence | 2010-10-17 | 2010-10-17 | 486          |
| 110       | 81700        | observations    | condition_occurrence | 2010-06-18 | 2010-06-19 | 486          |
| 172       | 87537        | observations    | condition_occurrence | 2009-01-25 | 2009-01-25 | 486          |
| 214       | 59068        | observations    | condition_occurrence | 2009-10-23 | 2009-10-23 | 486          |
| 220       | 47310        | observations    | condition_occurrence | 2008-11-26 | 2008-11-26 | 486          |

```YAML
---
- time_window
- - icd9
  - '412'
- :start: "-2y"
  :end: "-2y"

```

![Shift the window for all MIs back by 2 years](spec/15268bc45993d3f57ccf915877f91e48bdee684f24faa614249915833cac4af9.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2006-10-29 | 2006-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2006-08-25 | 2006-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2007-04-30 | 2007-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2008-02-12 | 2008-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2006-06-05 | 2006-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2007-07-19 | 2007-07-22 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2007-07-25 | 2007-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2006-11-16 | 2006-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2008-10-06 | 2008-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2007-01-28 | 2007-01-30 | 412          |

```YAML
---
- time_window
- - icd9
  - '412'
- :start: "-2m-2d"
  :end: 3d1y

```

![Expand the dates for all MIs to a window ranging from 2 months and 2 days prior to 1 year and 3 days after the MI](spec/cc960a268d51ccf2ebde657d36848f780213834844900018bce3d111843f7b0f.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-08-27 | 2009-11-01 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-06-23 | 2009-08-28 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-02-26 | 2010-05-03 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2009-12-10 | 2011-02-15 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-04-03 | 2009-06-08 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-05-17 | 2010-07-25 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-05-23 | 2010-07-28 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-09-14 | 2009-11-19 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-08-04 | 2011-10-09 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2008-11-26 | 2010-02-02 | 412          |

```YAML
---
- time_window
- - hospitalization
- :start: ''
  :end: start

```

![Collapse all hospitalizations' date ranges down to just the date of admission by leaving start_date unaffected and setting end_date to start_date](spec/aff055a65bcf745c075dc3f80b567ab40f1ce74cb9bcb4976d8044761b8aed32.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 1         | 95           | collections     | condition_occurrence | 2010-03-12 | 2010-03-12 | V4501        |
| 2         | 37           | collections     | condition_occurrence | 2009-04-12 | 2009-04-12 | 2724         |
| 2         | 96           | collections     | condition_occurrence | 2009-08-31 | 2009-08-31 | 7092         |
| 2         | 12           | collections     | condition_occurrence | 2009-09-17 | 2009-09-17 | 32723        |
| 2         | 43           | collections     | condition_occurrence | 2010-06-26 | 2010-06-26 | 7856         |
| 14        | 151          | collections     | condition_occurrence | 2008-09-12 | 2008-09-12 | 2724         |
| 17        | 93           | collections     | condition_occurrence | 2008-09-19 | 2008-09-19 | 33811        |
| 17        | 83           | collections     | condition_occurrence | 2010-05-22 | 2010-05-22 | 5845         |
| 17        | 122          | collections     | condition_occurrence | 2010-06-02 | 2010-06-02 | 4280         |
| 17        | 124          | collections     | condition_occurrence | 2010-06-16 | 2010-06-16 | V4365        |

```YAML
---
- time_window
- - icd9
  - '412'
- :start: end
  :end: start

```

![Nonsensical, but allowed: swap the start_date and end_date for a range](spec/6705af65d728c0d5c50d6c4d46253017a91eb459dbb1f40f92449f05d5562f4a.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-22 | 2009-07-19 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-30 | 2009-01-28 | 412          |

### Temporal Operators and Person Streams

Person streams carry a patient's date of birth in their date columns. This makes them almost useless when they are part of the L stream of a temporal operator. But person streams are useful as the R stream. By `time_window`ing the patient's date of birth, we can filter based on the patient's age like so:

```YAML
---
- after
- :left:
  - icd9
  - '412'
  :right:
  - time_window
  - - gender
    - Male
  - :start: 50y
    :end: 50y

```

![All MIs that occurred after a male patient's 50th birthday](spec/68fac940a32c7e40caacf8e560c61da552d57633d015ba98f2e98ec040a00c5b.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 93        | 82295        | observations    | condition_occurrence | 2009-11-08 | 2009-11-08 | 412          |
| 96        | 20748        | observations    | condition_occurrence | 2008-09-21 | 2008-09-24 | 412          |
| 109       | 89334        | observations    | condition_occurrence | 2010-07-06 | 2010-07-06 | 412          |
| 110       | 62592        | observations    | condition_occurrence | 2010-06-27 | 2010-06-27 | 412          |
| 131       | 172          | observations    | condition_occurrence | 2008-03-22 | 2008-03-23 | 412          |
| 149       | 28518        | observations    | condition_occurrence | 2008-04-07 | 2008-04-07 | 412          |
| 152       | 82988        | observations    | condition_occurrence | 2008-08-16 | 2008-08-16 | 412          |
| 152       | 84298        | observations    | condition_occurrence | 2010-11-22 | 2010-11-22 | 412          |

## Type Conversion

There are situations where it is appropriate to convert the type of a stream of results into a different type. In programmer parlance, we say "typecasting" or "casting", which is the terminology we'll use here. A good analogy and mnemonic for casting is to think of taking a piece of metal, say a candle holder, melting it down, and recasting it into, say, a lamp. We'll do something similar with streams. We'll take, for example, a condition_occurrence stream and recast it into a stream of person.

ConceptQL has two casting operators: person and death. GDM has no visit table to cast to. To find conditions and procedures that were reported in the same source record, such as the same claim, use the co_reported operator (see Co-reported Events).

### Casting to person

- Useful if we're just checking for the presence of a condition for a person
- E.g. We want to know *if* a person has an old MI, not when an MI or how many MIs occurred

```YAML
---
- person
- - icd9
  - '412'

```

![All People Who Had an MI](spec/8ed478d8c81a58a202d0c51348fca246df206fc24a0567b163d4e0bdab56ca46.png)

| person_id | criterion_id | criterion_table | criterion_domain | start_date | end_date   | source_value     |
| --------- | ------------ | --------------- | ---------------- | ---------- | ---------- | ---------------- |
| 11        | 11           | patients        | person           | 1934-02-01 | 1934-02-01 | 000489E7EAAD463F |
| 17        | 17           | patients        | person           | 1919-09-01 | 1919-09-01 | 0007F12A492FD25D |
| 38        | 38           | patients        | person           | 1922-12-01 | 1922-12-01 | 001731EB127233DA |
| 54        | 54           | patients        | person           | 1931-02-01 | 1931-02-01 | 001CAFF084B21E14 |
| 60        | 60           | patients        | person           | 1925-07-01 | 1925-07-01 | 001EA2F4DB30F105 |
| 66        | 66           | patients        | person           | 1920-04-01 | 1920-04-01 | 0021B3C854C968C8 |
| 73        | 73           | patients        | person           | 1925-09-01 | 1925-09-01 | 00237322613CFC3C |
| 77        | 77           | patients        | person           | 1929-03-01 | 1929-03-01 | 00244B6D9AB50F9B |
| 81        | 81           | patients        | person           | 1940-06-01 | 1940-06-01 | 0024E5A7B7272E75 |
| 88        | 88           | patients        | person           | 1922-05-01 | 1922-05-01 | 00291F39917544B1 |

### Casting to death

- Replaces each result with the death record of the result's person
- A person with no death record yields no results

```YAML
---
- death
- - icd9
  - '412'

```

![The Deaths of All People Who Had an MI](spec/8b20c1a598c4d0f7cae613f707f5eaa90da3293d7ac24bb5b12df278a8e69d57.png)

| person_id | criterion_id | criterion_table | criterion_domain | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | ---------------- | ---------- | ---------- | ------------ |
| 190       | 7            | deaths          | death            | 2009-09-01 | 2009-09-01 |              |

### Casting Loses All Original Information

After a result undergoes casting, it loses its original information. E.g. casting a condition_occurrence to a person loses the condition information and resets the start_date and end_date columns to the person's date of birth. As a side note, this is actually handy if a person stream's dates have been altered by a time_window operator and you want the original dates later on. Just cast the stream to person again and it will regain the date of birth.

### Casting as a way to fetch all rows

The casting operator doubles as a way to fetch all rows for a single type. Provide the casting operator with no upstream operator to get all rows as results:

```YAML
---
- death

```

![All death results in the database](spec/e281558c677a04df02e53dcc7fd6497a0d831e4037560cd13942b67ab10f98f4.png)

| person_id | criterion_id | criterion_table | criterion_domain | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | ---------------- | ---------- | ---------- | ------------ |
| 16        | 1            | deaths          | death            | 2010-12-01 | 2010-12-01 |              |
| 26        | 2            | deaths          | death            | 2009-07-01 | 2009-07-01 |              |
| 65        | 3            | deaths          | death            | 2009-01-01 | 2009-01-01 |              |
| 119       | 4            | deaths          | death            | 2008-09-01 | 2008-09-01 |              |
| 166       | 5            | deaths          | death            | 2008-07-01 | 2008-07-01 |              |
| 181       | 6            | deaths          | death            | 2010-07-01 | 2010-07-01 |              |
| 190       | 7            | deaths          | death            | 2009-09-01 | 2009-09-01 |              |
| 191       | 8            | deaths          | death            | 2009-09-01 | 2009-09-01 |              |
| 201       | 9            | deaths          | death            | 2008-05-01 | 2008-05-01 |              |
| 215       | 10           | deaths          | death            | 2008-01-01 | 2008-01-01 |              |

This comes in handy for situations like these:

```YAML
---
- person_filter
- :left:
  - gender
  - Male
  :right:
  - death

```

![All Male patients who died](spec/bb369188911f61bfd851f575d6e8dcc96f1328f4b58721e3fb32932985db1025.png)

| person_id | criterion_id | criterion_table | criterion_domain | start_date | end_date   | source_value     |
| --------- | ------------ | --------------- | ---------------- | ---------- | ---------- | ---------------- |
| 16        | 16           | patients        | person           | 1934-01-01 | 1934-01-01 | 0007E57CC13CE880 |
| 65        | 65           | patients        | person           | 1936-01-01 | 1936-01-01 | 0021940CF994C374 |
| 181       | 181          | patients        | person           | 1939-11-01 | 1939-11-01 | 005E0AB5172E715F |
| 190       | 190          | patients        | person           | 1939-07-01 | 1939-07-01 | 0060C263DA4EBBAF |
| 191       | 191          | patients        | person           | 1928-12-01 | 1928-12-01 | 0061141AB18FFA96 |
| 201       | 201          | patients        | person           | 1949-06-01 | 1949-06-01 | 00653DC86A0E30D8 |

## Filtering by People

Often we want to filter out a set of results by people. For instance, say we wanted to find all MIs for all males. We'd use the person_filter operator for that. Like the Except operator, it takes a left-hand stream and a right-hand stream.

Unlike the `except` operator, the person_filter operator will use all types of all streams in the right-hand side to filter out results in all types of all streams on the left hand side.

```YAML
---
- person_filter
- :left:
  - icd9
  - '412'
  :right:
  - gender
  - Male

```

![All MI Conditions for people who are male](spec/0360fc0c2b7a88fd82ffc4d13387b76766649d5d42aa8f9349bbf60a81ac6119.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 93        | 82295        | observations    | condition_occurrence | 2009-11-08 | 2009-11-08 | 412          |
| 96        | 20748        | observations    | condition_occurrence | 2008-09-21 | 2008-09-24 | 412          |
| 109       | 89334        | observations    | condition_occurrence | 2010-07-06 | 2010-07-06 | 412          |
| 110       | 62592        | observations    | condition_occurrence | 2010-06-27 | 2010-06-27 | 412          |
| 131       | 172          | observations    | condition_occurrence | 2008-03-22 | 2008-03-23 | 412          |
| 149       | 28518        | observations    | condition_occurrence | 2008-04-07 | 2008-04-07 | 412          |
| 152       | 82988        | observations    | condition_occurrence | 2008-08-16 | 2008-08-16 | 412          |
| 152       | 84298        | observations    | condition_occurrence | 2010-11-22 | 2010-11-22 | 412          |

But we can get crazier. The right-hand side doesn't have to be a person stream. If a non-person stream is used in the right-hand side, the person_filter will cast all right-hand streams to person first and use the union of those streams:

```YAML
---
- person_filter
- :left:
  - icd9
  - '412'
  :right:
  - cpt
  - '99214'

```

![All MI Conditions for people who had an office visit at some point in the data](spec/26fd52b5ac55438dd9f81b4a3f3913f1058c9f225c8a5e129007c1e9413d5881.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |

```YAML
---
- person_filter
- :left:
  - icd9
  - '412'
  :right:
  - person
  - - cpt
    - '99214'

```

![All MI Conditions for people who had an office visit at some point in the data (an explicit representation of what's happening in the diagram above)](spec/e1cb0863b21e14256d61a54200316791f6547c78ba2f0156c110f4500f9bbd49.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |

```YAML
---
- person_filter
- :left:
  - icd9
  - '412'
  :right:
  - union
  - - cpt
    - '99214'
  - - gender
    - Male

```

![All MI Conditions for people who are Male OR had an office visit at some point in the data](spec/5d331d74c460d75814b2d3138a9b7d90b5ddb2dcd85e1f5f260d183745fc3a1e.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |

And don't forget the left-hand side can have multiple types of streams:

```YAML
---
- person_filter
- :left:
  - union
  - - icd9
    - '412'
  - - cpt
    - '99214'
  :right:
  - gender
  - Male

```

![Yields two streams: a stream of all MI Conditions for people who are Male and a stream of all office visit Procedures for people who are Male](spec/c93dd18894a245a5647f99e1867d3779e4cd34c9c8f8860600ff0c837a5ffa53.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 2         | 58127        | observations    | procedure_occurrence | 2009-07-03 | 2009-07-03 | 99214        |
| 2         | 83339        | observations    | procedure_occurrence | 2009-12-02 | 2009-12-02 | 99214        |
| 5         | 38313        | observations    | procedure_occurrence | 2008-12-14 | 2008-12-14 | 99214        |
| 5         | 76788        | observations    | procedure_occurrence | 2009-07-04 | 2009-07-04 | 99214        |
| 5         | 63847        | observations    | procedure_occurrence | 2009-12-21 | 2009-12-21 | 99214        |
| 6         | 48992        | observations    | procedure_occurrence | 2009-09-12 | 2009-09-12 | 99214        |
| 6         | 76651        | observations    | procedure_occurrence | 2010-02-23 | 2010-02-23 | 99214        |
| 7         | 63797        | observations    | procedure_occurrence | 2008-08-13 | 2008-08-13 | 99214        |
| 7         | 59555        | observations    | procedure_occurrence | 2008-09-21 | 2008-09-21 | 99214        |
| 7         | 71597        | observations    | procedure_occurrence | 2008-09-22 | 2008-09-22 | 99214        |

## Sub-algorithms within a Larger Algorithm

If a algorithm is particularly complex, or has a stream of results that are used more than once, it can be helpful to break the algorithm into a set of sub-algorithms. This can be done using the `label` options and the `recall` operator.

### `label` option

Any ConceptQL operator can be assigned a label. The label simply provides a way to apply a brief description to an operator, generally, what kind of results the operator is producing. Any operator that has a label can be accessed via the `recall` operator.

### `recall` operator

- Takes 1 argument
  - The "label" of an operator from which you'd like to pull the exact same set of results

A stream must have a `label` before `recall` can use it.

```YAML
---
- first
- - union
  - - provenance
    - - icd9
      - '412'
      - :label: Heart Attack
    - inpatient
  - - before
    - :left:
      - provenance
      - - recall
        - Heart Attack
      - outpatient
      - :label: Outpatient Heart Attack
      :right:
      - time_window
      - - recall
        - Outpatient Heart Attack
      - :start: "-30d"
        :end: '0'
      :label: Earliest of Two Outpatient Heart Attacks

```

![Save away a stream of results to build the 1 inpatient, 2 outpatient pattern used in claims data algorithms](spec/30e432f256d528ee828a7d97e550e110277841bce042da718ee253134dbeaf3f.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |
| 88        | 1572         | observations    | condition_occurrence | 2009-01-03 | 2009-01-09 | 412          |
| 131       | 172          | observations    | condition_occurrence | 2008-03-22 | 2008-03-23 | 412          |
| 161       | 963          | observations    | condition_occurrence | 2009-10-25 | 2009-10-29 | 412          |
| 177       | 507          | observations    | condition_occurrence | 2009-06-13 | 2009-06-16 | 412          |
| 230       | 523          | observations    | condition_occurrence | 2008-03-14 | 2008-03-21 | 412          |

ConceptQL also has a `one_in_two_out` operator that implements this pattern in a single operator.

## Algorithms within Algorithms

One of the main motivations behind keeping ConceptQL so flexible is to allow users to build ConceptQL statements from other ConceptQL statements. This section describes how this feature works.

Say a ConceptQL statement gathers all pneumonia diagnoses (ICD-9 486) and hospital visits (CPT 99232, subsequent hospital care) that were reported in the same source record:

```YAML
---
- co_reported
- - icd9
  - '486'
- - cpt
  - '99232'

```

![All Pneumonia Diagnoses and Hospital Visits reported in the same source record](spec/814fa803d0ba09d73b7bb33177d043c26b681f5c621e9d76dc5c2e18dc852770.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 63        | 61990        | observations    | condition_occurrence | 2009-07-02 | 2009-07-04 | 486          |
| 63        | 61991        | observations    | condition_occurrence | 2009-07-02 | 2009-07-04 | 486          |
| 63        | 61994        | observations    | procedure_occurrence | 2009-07-02 | 2009-07-04 | 99232        |
| 63        | 61995        | observations    | procedure_occurrence | 2009-07-02 | 2009-07-04 | 99232        |
| 83        | 38139        | observations    | condition_occurrence | 2008-03-02 | 2008-03-02 | 486          |
| 83        | 38140        | observations    | procedure_occurrence | 2008-03-02 | 2008-03-02 | 99232        |
| 85        | 80214        | observations    | condition_occurrence | 2008-08-24 | 2008-08-30 | 486          |
| 85        | 80215        | observations    | condition_occurrence | 2008-08-24 | 2008-08-30 | 486          |
| 85        | 80216        | observations    | procedure_occurrence | 2008-08-24 | 2008-08-30 | 99232        |
| 85        | 80217        | observations    | procedure_occurrence | 2008-08-24 | 2008-08-30 | 99232        |

The "algorithm" operator represents a stored ConceptQL statement in a new statement. It takes the ID of the stored statement. ConceptQL reads the stored statement from the `statement` column of the `concepts` table, in the row whose `concept_id` is that ID. So, assuming that the ID 2031 represents the algorithm defined above, we could gather all the people with those records like this:

```YAML
---
- person
- - algorithm
  - 2031

```

![All People with a Pneumonia Diagnosis and a Hospital Visit reported in the same source record](spec/eaa8e3fcbe133f6962f97ae3de3714e943d5e38c3e1cecfe62c5a1972866228f.png)

| person_id | criterion_id | criterion_table | criterion_domain | start_date | end_date   | source_value     |
| --------- | ------------ | --------------- | ---------------- | ---------- | ---------- | ---------------- |
| 63        | 63           | patients        | person           | 1964-05-01 | 1964-05-01 | 00205821D74AA7D8 |
| 83        | 83           | patients        | person           | 1963-05-01 | 1963-05-01 | 002578091E1953AF |
| 85        | 85           | patients        | person           | 1937-01-01 | 1937-01-01 | 0025ACAB19F5DEC0 |
| 141       | 141          | patients        | person           | 1933-04-01 | 1933-04-01 | 0040CF7315D51D01 |
| 143       | 143          | patients        | person           | 1945-05-01 | 1945-05-01 | 00422125F788CC20 |
| 149       | 149          | patients        | person           | 1943-02-01 | 1943-02-01 | 0045A5AFF076CBE6 |
| 150       | 150          | patients        | person           | 1936-01-01 | 1936-01-01 | 0046020E72E1CBFD |
| 176       | 176          | patients        | person           | 1939-03-01 | 1939-03-01 | 0057DAC8F6C528CB |
| 178       | 178          | patients        | person           | 1928-06-01 | 1928-06-01 | 0058B2A556D74DC2 |
| 214       | 214          | patients        | person           | 1914-07-01 | 1914-07-01 | 006D1BD234E5C844 |

ConceptQL replaces the algorithm operator with the stored statement when it reads the statement, so the diagram above shows the stored statement. The result of nesting one algorithm within another is exactly the same had we taken algorithm operator and replaced it with the ConceptQL statement for the algorithm it represents.

```YAML
---
- person
- - co_reported
  - - icd9
    - '486'
  - - cpt
    - '99232'

```

![All People with a Pneumonia Diagnosis and a Hospital Visit reported in the same source record (same as above)](spec/2b0e2bd4016c9888be0d4f3afe2e71d57a05796cbb396a786e447b33f5428897.png)

| person_id | criterion_id | criterion_table | criterion_domain | start_date | end_date   | source_value     |
| --------- | ------------ | --------------- | ---------------- | ---------- | ---------- | ---------------- |
| 63        | 63           | patients        | person           | 1964-05-01 | 1964-05-01 | 00205821D74AA7D8 |
| 83        | 83           | patients        | person           | 1963-05-01 | 1963-05-01 | 002578091E1953AF |
| 85        | 85           | patients        | person           | 1937-01-01 | 1937-01-01 | 0025ACAB19F5DEC0 |
| 141       | 141          | patients        | person           | 1933-04-01 | 1933-04-01 | 0040CF7315D51D01 |
| 143       | 143          | patients        | person           | 1945-05-01 | 1945-05-01 | 00422125F788CC20 |
| 149       | 149          | patients        | person           | 1943-02-01 | 1943-02-01 | 0045A5AFF076CBE6 |
| 150       | 150          | patients        | person           | 1936-01-01 | 1936-01-01 | 0046020E72E1CBFD |
| 176       | 176          | patients        | person           | 1939-03-01 | 1939-03-01 | 0057DAC8F6C528CB |
| 178       | 178          | patients        | person           | 1928-06-01 | 1928-06-01 | 0058B2A556D74DC2 |
| 214       | 214          | patients        | person           | 1914-07-01 | 1914-07-01 | 006D1BD234E5C844 |

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

```YAML
---
- numeric
- 2
- - icd9
  - '412'

```

![All MIs, setting value_as_number to 2](spec/d39452b58257c95a7cba07afed4877417b0c227f3690e2bff22c9eca89eac845.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value | value_as_number |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ | --------------- |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          | 2.0             |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          | 2.0             |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          | 2.0             |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          | 2.0             |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          | 2.0             |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          | 2.0             |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          | 2.0             |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          | 2.0             |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          | 2.0             |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          | 2.0             |

With a `numeric` operator defined, we can use the `sum` operator to sum the values for each patient and type. This allows us to implement the Charlson comorbidity algorithm:

```YAML
---
- sum
- - union
  - - numeric
    - 1
    - - person
      - - icd9
        - '412'
  - - numeric
    - 2
    - - person
      - - icd9
        - '278.02'

```

![](spec/ba572c4f4dbade65be55f141df16cf7b3e7d09e0aec4e4e5debc4f2075277371.png)

| person_id | criterion_id | criterion_table | criterion_domain | start_date | end_date   | source_value     | value_as_number |
| --------- | ------------ | --------------- | ---------------- | ---------- | ---------- | ---------------- | --------------- |
| 11        | 0            | patients        | person           | 1934-02-01 | 1934-02-01 | 000489E7EAAD463F | 1.0             |
| 17        | 0            | patients        | person           | 1919-09-01 | 1919-09-01 | 0007F12A492FD25D | 3.0             |
| 34        | 0            | patients        | person           | 1919-10-01 | 1919-10-01 | 00151A878F9A2C0D | 2.0             |
| 38        | 0            | patients        | person           | 1922-12-01 | 1922-12-01 | 001731EB127233DA | 1.0             |
| 54        | 0            | patients        | person           | 1931-02-01 | 1931-02-01 | 001CAFF084B21E14 | 1.0             |
| 55        | 0            | patients        | person           | 1924-12-01 | 1924-12-01 | 001D0E59C94130D3 | 2.0             |
| 60        | 0            | patients        | person           | 1925-07-01 | 1925-07-01 | 001EA2F4DB30F105 | 1.0             |
| 66        | 0            | patients        | person           | 1920-04-01 | 1920-04-01 | 0021B3C854C968C8 | 1.0             |
| 73        | 0            | patients        | person           | 1925-09-01 | 1925-09-01 | 00237322613CFC3C | 1.0             |
| 77        | 0            | patients        | person           | 1929-03-01 | 1929-03-01 | 00244B6D9AB50F9B | 1.0             |

### Counting

The `count` operator groups identical results and stores the number of results in each group in the value_as_number column. Two results are identical only when all of their columns match, including criterion_id. So `count` does not count the events of each person. Casting a stream to person first does not help, because the cast yields one result for each person.

To count the events of each person, set value_as_number to 1 with `numeric`, and then use `sum`:

```YAML
---
- sum
- - numeric
  - 1
  - - icd9
    - '486'

```

![Count the number of times each person had pneumonia](spec/385ede8312e323fa1ae2337c303c8e89f252ebcb8ba229961fa3af1a3caec886.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value | value_as_number |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ | --------------- |
| 14        | 0            | observations    | condition_occurrence | 2008-09-12 | 2009-04-05 | 486          | 2.0             |
| 17        | 0            | observations    | condition_occurrence | 2009-05-21 | 2009-05-21 | 486          | 1.0             |
| 19        | 0            | observations    | condition_occurrence | 2008-02-02 | 2008-02-03 | 486          | 1.0             |
| 23        | 0            | observations    | condition_occurrence | 2009-08-18 | 2010-02-17 | 486          | 3.0             |
| 25        | 0            | observations    | condition_occurrence | 2009-07-08 | 2009-07-08 | 486          | 1.0             |
| 27        | 0            | observations    | condition_occurrence | 2010-09-30 | 2010-09-30 | 486          | 1.0             |
| 28        | 0            | observations    | condition_occurrence | 2009-09-12 | 2009-09-12 | 486          | 1.0             |
| 38        | 0            | observations    | condition_occurrence | 2010-02-24 | 2010-02-24 | 486          | 3.0             |
| 44        | 0            | observations    | condition_occurrence | 2009-09-07 | 2010-08-30 | 486          | 6.0             |
| 51        | 0            | observations    | condition_occurrence | 2008-03-08 | 2008-10-18 | 486          | 2.0             |

We could do dumb things like count the number of times a row shows up in a union:

```YAML
---
- count
- - union
  - - icd9
    - '412'
  - - provenance
    - - icd9
      - '412'
    - inpatient

```

![All rows with a value of 2 would be rows that were both MI and from an inpatient record](spec/ecede6b94c97cf0b036a664e4df704d119be7c31607a1defe6eb77f294fd1393.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value | value_as_number |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ | --------------- |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          | 1               |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          | 1               |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          | 1               |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          | 1               |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          | 1               |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          | 2               |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          | 1               |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          | 1               |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          | 1               |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          | 2               |

#### Numeric Value Comparison

The `numeric_filter` operator takes one stream. It passes along the results whose value_as_number is in a range, and it drops results whose value_as_number is NULL. It takes two options, and both are inclusive:

- greater_than_or_equal_to
- less_than_or_equal_to

```YAML
---
- person
- - numeric_filter
  - - sum
    - - numeric
      - 1
      - - icd9
        - '412'
  - :greater_than_or_equal_to: 2

```

![People with more than 1 MI](spec/0d8546d33c77d25b522ae23b74c87bf9ee77f5564c6de688af8a2b270b615cfb.png)

| person_id | criterion_id | criterion_table | criterion_domain | start_date | end_date   | source_value     | value_as_number |
| --------- | ------------ | --------------- | ---------------- | ---------- | ---------- | ---------------- | --------------- |
| 17        | 17           | patients        | person           | 1919-09-01 | 1919-09-01 | 0007F12A492FD25D |                 |
| 88        | 88           | patients        | person           | 1922-05-01 | 1922-05-01 | 00291F39917544B1 |                 |
| 152       | 152          | patients        | person           | 1927-07-01 | 1927-07-01 | 00490754761BC1C2 |                 |
| 177       | 177          | patients        | person           | 1939-02-01 | 1939-02-01 | 0057EDCE5B633B19 |                 |
| 187       | 187          | patients        | person           | 1936-01-01 | 1936-01-01 | 006084B3FA2A151C |                 |
| 212       | 212          | patients        | person           | 1940-01-01 | 1940-01-01 | 006B004741EB5AE9 |                 |
| 213       | 213          | patients        | person           | 1940-02-01 | 1940-02-01 | 006C7FC30305A339 |                 |
| 214       | 214          | patients        | person           | 1914-07-01 | 1914-07-01 | 006D1BD234E5C844 |                 |
| 220       | 220          | patients        | person           | 1927-11-01 | 1927-11-01 | 0070946DE04C2014 |                 |
| 223       | 223          | patients        | person           | 1926-05-01 | 1926-05-01 | 0071E2E641B73233 |                 |

### numeric as selection operator

Numeric doesn't have to take a stream. If it doesn't have a stream as an argument, it acts like a selection operator much like date_range. It yields one person result for each patient, with value_as_number set to its value.

```YAML
---
- numeric
- 1

```

![All patients, each with value_as_number set to 1](spec/3d6b85dbd283c27fa65bc58746c7fe1e58ab76962e72460dbcf85e336bf47e51.png)

| person_id | criterion_id | criterion_table | criterion_domain | start_date | end_date   | source_value     | value_as_number |
| --------- | ------------ | --------------- | ---------------- | ---------- | ---------- | ---------------- | --------------- |
| 1         | 1            | patients        | person           | 1923-05-01 | 1923-05-01 | 00013D2EFD8E45D1 | 1.0             |
| 2         | 2            | patients        | person           | 1943-01-01 | 1943-01-01 | 00016F745862898F | 1.0             |
| 3         | 3            | patients        | person           | 1936-09-01 | 1936-09-01 | 0001FDD721E223DC | 1.0             |
| 4         | 4            | patients        | person           | 1941-06-01 | 1941-06-01 | 00021CA6FF03E670 | 1.0             |
| 5         | 5            | patients        | person           | 1936-08-01 | 1936-08-01 | 00024B3D2352D2D0 | 1.0             |
| 6         | 6            | patients        | person           | 1943-10-01 | 1943-10-01 | 0002DAE1C81CC70D | 1.0             |
| 7         | 7            | patients        | person           | 1922-07-01 | 1922-07-01 | 0002F28CE057345B | 1.0             |
| 8         | 8            | patients        | person           | 1935-09-01 | 1935-09-01 | 000308435E3E5B76 | 1.0             |
| 9         | 9            | patients        | person           | 1976-09-01 | 1976-09-01 | 000345A39D4157C9 | 1.0             |
| 10        | 10           | patients        | person           | 1938-10-01 | 1938-10-01 | 00036A21B65B0206 | 1.0             |

#### sum

- Takes a stream of results and does some wild things
  - Groups the results by all of their columns except criterion_id, start_date, end_date, and value_as_number, which puts the results of each person and type in one group when they share a source_value
    - Sums the value_as_number column within that grouping
    - Sets start_date to the earliest start_date in the group
    - Sets the end_date to the most recent end_date in the group
    - Sets criterion_id to 0 since there is no particular single row that the result refers to anymore

## Appendix A - Selection Operators

ConceptQL creates a vocabulary operator for each vocabulary in its vocabulary list (`config/vocabularies.csv`) and in its vocabulary database. This table lists the most common selection operators.

| Operator Name       | Stream Type          | Arguments                                | Returns                                                        |
| ------------------- | -------------------- | ---------------------------------------- | -------------------------------------------------------------- |
| cpt                 | procedure_occurrence | 1 or more CPT codes                      | All clinical codes that match any of the CPT codes             |
| icd9                | condition_occurrence | 1 or more ICD-9-CM diagnosis codes       | All clinical codes that match any of the ICD-9 codes           |
| icd9_procedure      | procedure_occurrence | 1 or more ICD-9-CM procedure codes       | All clinical codes that match any of the ICD-9 procedure codes |
| icd10cm             | condition_occurrence | 1 or more ICD-10-CM codes                | All clinical codes that match any of the ICD-10-CM codes       |
| hcpcs               | procedure_occurrence | 1 or more HCPCS codes                    | All clinical codes that match any of the HCPCS codes           |
| loinc               | observation          | 1 or more LOINC codes                    | All clinical codes that match any of the LOINC codes           |
| ndc                 | drug_exposure        | 1 or more NDC codes                      | All clinical codes that match any of the NDC codes             |
| rxnorm              | drug_exposure        | 1 or more RxNorm codes                   | All clinical codes that match any of the RxNorm codes          |
| snomed              | condition_occurrence | 1 or more SNOMED codes                   | All clinical codes that match any of the SNOMED codes          |
| gender              | person               | 1 or more of Male, Female, and Unknown   | All patients whose gender matches any of the arguments         |
| race                | person               | 1 or more race names or race concept IDs | All patients whose race matches any of the arguments           |
| death               | death                | None                                     | All death records                                              |
| information_periods | observation_period   | None                                     | All information periods                                        |
| date_range          | person               | A start date and an end date             | One result for each patient, with the given dates              |

## Appendix B - Algorithm Showcase

Here I take some algorithms from [OMOP's Health Outcomes of Interest](http://omop.org/HOI) and turn them into ConceptQL statements to give more examples. I truncated some of the sets of codes to help ensure the diagrams didn't get too large.

### Acute Kidney Injury - Narrow Definition and diagnositc procedure

- ICD-9 of 584 (584.5 through 584.9)
- AND
  - ICD-9 procedure codes of 39.95 or 54.98 within 60 days after diagnosis
- AND NOT
  - A diagnostic code of chronic dialysis any time before initial diagnosis
    - V45.1, V56.0, V56.31, V56.32, V56.8

```YAML
---
- during
- :left:
  - except
  - :left:
    - icd9
    - '584.5'
    - '584.6'
    - '584.7'
    - '584.8'
    - '584.9'
    :right:
    - after
    - :left:
      - icd9
      - '584.5'
      - '584.6'
      - '584.7'
      - '584.8'
      - '584.9'
      :right:
      - icd9
      - V45.1
      - V56.0
      - V56.31
      - V56.32
      - V56.8
  :right:
  - time_window
  - - icd9_procedure
    - '39.95'
    - '54.98'
  - :start: '0'
    :end: 60d

```

![](spec/58b1555ee5f9e9b2d2adfca6683c2c1e29498347e207e7406b1fe3265ba619b4.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 153       | 102          | observations    | condition_occurrence | 2010-01-29 | 2010-02-08 | 5849         |

### Mortality after Myocardial Infarction #3

- Person Died
- And Occurrence of an acute MI (ICD-9 410.x1, initial episode of care) prior to death
- And either
  - MI diagnosis within 30 days prior to 410
  - MI therapy within 60 days after 410

```YAML
---
- during
- :left:
  - before
  - :left:
    - icd9
    - '410.01'
    - '410.11'
    - '410.21'
    - '410.31'
    - '410.41'
    - '410.51'
    - '410.61'
    - '410.71'
    - '410.81'
    - '410.91'
    :right:
    - death
  :right:
  - union
  - - time_window
    - - union
      - - cpt
        - 0146T
        - '75898'
        - '82554'
        - '92980'
        - '93010'
        - '93233'
        - '93508'
        - '93540'
        - '93545'
      - - icd9_procedure
        - '00.24'
        - '36.02'
        - '89.53'
        - '89.57'
        - '89.69'
      - - loinc
        - 10839-9
        - 13969-1
        - 18843-3
        - 2154-3
        - 33204-9
        - 48425-3
        - 49259-5
        - 6597-9
        - 8634-8
    - :start: "-30d"
      :end: '0'
  - - time_window
    - - union
      - - cpt
        - 0146T
        - '75898'
        - '82554'
        - '92980'
        - '93010'
        - '93233'
      - - icd9_procedure
        - '00.24'
        - '36.02'
        - '89.53'
        - '89.57'
        - '89.69'
    - :start: ''
      :end: 60d

```

![](spec/f6b358f3006c217809558dc8b9ebe7060623ac72068a96fdf5b72240d8aed13a.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 191       | 64752        | observations    | condition_occurrence | 2008-03-11 | 2008-03-11 | 41071        |
| 191       | 89727        | observations    | condition_occurrence | 2008-12-27 | 2008-12-27 | 41071        |

### GI Ulcer Hospitalization 2 (5000001002)

- Occurrence of GI Ulcer diagnostic code
- Hospitalization at time of diagnostic code
- At least one diagnostic procedure during same hospitalization

GDM has no visit table. In this statement, co_reported keeps the ulcer diagnoses and the diagnostic procedures that were reported in the same source record. Then during keeps those that occurred during a hospitalization. A shared source record is stricter than a shared hospitalization.

```YAML
---
- during
- :left:
  - co_reported
  - - icd9
    - '531.00'
    - '531.40'
    - '531.90'
    - '532.40'
    - '532.90'
    - '533.40'
    - '533.90'
    - '534.40'
    - '534.90'
  - - union
    - - cpt
      - '0008T'
      - 3142F
      - '43205'
      - '43236'
      - '76975'
      - '91110'
      - '91111'
    - - hcpcs
      - B4081
      - B4082
    - - icd9_procedure
      - '42.22'
      - '42.23'
      - '44.13'
      - '45.13'
      - '52.21'
      - '97.01'
    - - loinc
      - 16125-7
      - 17780-8
      - 40820-3
      - 50320-1
      - 5177-1
      - 7901-2
  :right:
  - hospitalization

```

![GI Ulcer diagnoses and diagnostic procedures reported in the same source record during a hospitalization](spec/1f7c9cec3ac4993fb25c83a889d5a2ddf1739e8cf58fb922a59b141e2b4a7cf4.png)

`No Results found.`

## Appendix C - Under Development

ConceptQL is not yet fully specified. These are modifications/enhancements that are under consideration. These ideas are most likely not completely refined and might actually represent changes that would fundamentally break ConceptQL.

### Todo List

1. Handle costs
   - How do we aggregate?
2. How do we count?
3. How do we handle missing values in streams?
   - For instance, missing DoB on patient?
4. What does it mean to pass a date range as an L stream?
   - I'm thinking we pass through no results
   - Turns out that, as implemented, a date_range is really a person_stream where the start and end dates represent the range (instead of the date of birth) so we're probably OK
5. How do we want to look up standard vocab concepts?
   - I think Marc’s approach is a bit heavy-handed

Some statements maybe very useful and it would be handy to reuse the bulk of the statement, but perhaps vary just a few things about it. ConceptQL could use variables to represent sub-expressions. A variable operator would be a place holder to say "some criteria set belongs here". That variable could be defined in another part of the criteria set and would be used in all places the variable operator appears. ConceptQL does not have a variable operator. The `label` option and the `recall` operator reuse a stream within one statement.

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
    - Hm. This feels a bit less like a good idea now
- string
  - source_value?
  - Boy, this one is even harder to default

```YAML
---
- icd9
- '412'

```

![All MIs, defaulting value_as_number to 1, value_as_concept_id to the concept ID for 412, value_as_string to the source code](spec/f6b4fc31703cfb6327bbbd4614af8bb72da6d39fa3d53ada63a70157f2fad80e.png)

| person_id | criterion_id | criterion_table | criterion_domain     | start_date | end_date   | source_value |
| --------- | ------------ | --------------- | -------------------- | ---------- | ---------- | ------------ |
| 11        | 82614        | observations    | condition_occurrence | 2008-10-29 | 2008-10-29 | 412          |
| 17        | 27269        | observations    | condition_occurrence | 2008-08-25 | 2008-08-25 | 412          |
| 17        | 46165        | observations    | condition_occurrence | 2009-04-30 | 2009-04-30 | 412          |
| 38        | 40556        | observations    | condition_occurrence | 2010-02-12 | 2010-02-12 | 412          |
| 54        | 74606        | observations    | condition_occurrence | 2008-06-05 | 2008-06-05 | 412          |
| 60        | 986          | observations    | condition_occurrence | 2009-07-19 | 2009-07-22 | 412          |
| 66        | 16171        | observations    | condition_occurrence | 2009-07-25 | 2009-07-25 | 412          |
| 73        | 52843        | observations    | condition_occurrence | 2008-11-16 | 2008-11-16 | 412          |
| 77        | 58165        | observations    | condition_occurrence | 2010-10-06 | 2010-10-06 | 412          |
| 81        | 1405         | observations    | condition_occurrence | 2009-01-28 | 2009-01-30 | 412          |

### `as` Option for Filter

The filter operator (see Set Operators) keeps left-hand results that also appear in the right-hand stream. An `as` option could temporarily cast the left-hand and right-hand streams to the type it names, and then keep the left-hand results whose cast results appear on both sides. That would be handy for keeping procedures that coincide with conditions without fully casting the streams. With `"as": "person"`, filter would behave like person_filter. ConceptQL does not have this option.

### AS option for Except

Like the proposed `as` option for filter, add an `as` option to the Except operator. This would simplify some of the algorithms I've developed.

\[^AIA\]: J. Allen. Maintaining knowledge about temporal intervals. Communications of the ACM (1983) vol. 26 (11) pp. 832-843
