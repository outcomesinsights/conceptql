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

We are writing a tool that can read research algorithms defined in ConceptQL.  The tool can create a diagram for the algorithm which makes it easy to visualize and understand.  The tool can also translate the algorithm into a SQL query which runs against data structured in [OMOP's Common Data Model (CDM)](http://omop.org/CDM).  The purpose of the CDM is to standardize the format and content of observational data, so standardized applications, tools and methods can be applied to them.

For instance, using ConceptQL we can take a statement that looks like this:

```YAML
:icd9: '412'
```

And generate a diagram that looks like this:


```YAML
---
- icd9
- '412'

```

![](spec/f6b4fc31703cfb6327bbbd4614af8bb72da6d39fa3d53ada63a70157f2fad80e.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |

And generate SQL that looks like this:

```SQL
SELECT *
FROM cdm_data.condition_occurrence AS co
JOIN vocabulary.source_to_concept_map AS scm ON (c.condition_concept_id = scm.target_concept_id)
WHERE scm.source_code IN ('412')
AND scm.source_vocabulary_id = 2
AND scm.source_code = co.condition_source_value
```

As stated above, one of the goals of ConceptQL is to make it easy to assemble fairly complex queries without having to roll up our sleeves and write raw SQL.  To accommodate this complexity, ConceptQL itself has some complexities of its own.  That said, we believe ConceptQL will help researchers define, hone, and share their research algorithms.

## ConceptQL Overview

### What ConceptQL Looks Like

I find seeing examples to be the quickest way to get a sense of a language.  Here is a trivial example to whet your appetite.  The example is in YAML, but could just as easily be in JSON or any other markup language capable of representing nested sets of heterogeneous arrays and hashes.  In fact, the ConceptQL "language" is a just set of nested hashes and arrays representing search criteria and some set operations and temporal operations to glue those criteria together.

```YAML
# Example 1: A simple example in YAML
# This is just a simple hash with a key of :icd9 and a value of 412
# This example will search the condition_occurrence table for all conditions that match the ICD-9 code 412.
---
:icd9: '412'
```

### ConceptQL Diagrams

Reading ConceptQL in YAML or JSON seems hard to me.  I prefer to explore ConceptQL using directed graphs.  For instance, the diagram for the simple example listed in YAML above is:


```YAML
---
- icd9
- '412'

```

![](spec/f6b4fc31703cfb6327bbbd4614af8bb72da6d39fa3d53ada63a70157f2fad80e.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |

Each oval depicts a "operator", or rather, a ConceptQL expression.  An arrow between a pair of operators indicates that the results from the operator on the tail of the arrow pass on to the operator at the head of the arrow.  A simple example should help here:


```YAML
---
- first
- - cpt
  - '99214'

```

![](spec/39d6a8eb71cae51b1d6937c97134e51f04fd47c54535ff0915fe6a8b4f197fb2.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 2 | 48 | procedure_occurrence | 2009-07-03 | 2009-07-03 | 99214 |
| 5 | 118 | procedure_occurrence | 2008-12-14 | 2008-12-14 | 99214 |
| 6 | 167 | procedure_occurrence | 2009-09-12 | 2009-09-12 | 99214 |
| 7 | 376 | procedure_occurrence | 2008-08-13 | 2008-08-13 | 99214 |
| 8 | 609 | procedure_occurrence | 2008-02-27 | 2008-02-27 | 99214 |
| 9 | 652 | procedure_occurrence | 2009-09-11 | 2009-09-11 | 99214 |
| 10 | 681 | procedure_occurrence | 2009-05-09 | 2009-05-09 | 99214 |
| 11 | 758 | procedure_occurrence | 2008-06-17 | 2008-06-17 | 99214 |
| 12 | 847 | procedure_occurrence | 2008-02-11 | 2008-02-11 | 99214 |
| 13 | 1102 | procedure_occurrence | 2008-01-24 | 2008-01-24 | 99214 |

The diagram above reads "get all procedures that match the CPT 99214 (Office Visit) and then filter them down to the first occurrence for each person".  The diagram is much more terse than that and to accurately read the diagram, you need a lot of implicit knowledge about how each operator operates.  Fortunately, this document will (hopefully) impart that knowledge to you.

Please note that all of my diagrams end with an arrow pointing at nothing.  You'll see why soon.

### Think of Results as a Stream

I draw my ConceptQL diagrams with leaf operators at the top and the "trunk" operators at the bottom.  I like to think of the results of a ConceptQL statement as a flowing stream of data.  The leaf operators, or operators that gather results out of the database, act like tributaries.  The results flow downwards and either join with other results, or filter out other results until the streams emerge at the bottom of the diagram.  Think of each arrow as a stream of results, flowing down through one operator to the next.

The trailing arrow in the diagrams serves as a reminder that ConceptQL yields a stream of results.

### Streams have Types

You might have noticed that the operators and edges in the diagrams often have a color.  That color represents what "type" of stream the operator or edge represents.  There are many types in ConceptQL, and you'll notice they are __strongly__ correlated with the tables found in [CDM v4.0](http://omop.org/CDM):

- condition_occurrence
    - red
- death
    - brown
- drug_cost
    - TBD
- drug_exposure
    - purple
- observation
    - TBD
- payer_plan_period
    - TBD
- person
    - blue
- procedure_cost
    - gold
- procedure_occurrence
    - green
- visit_occurrence
    - orange

Each stream has a point of origin (essentially, the table from which we pulled the results for a stream).  Based on that origin, each stream will have a particular type.  The stream carries this type information as it moves through each operator.  When certain operators, particularly set and temporal operators, need to perform filtering, they can use this type information to determine how to best filter a stream.  There will be much more discussion about types woven throughout this document.  For now, it is sufficient to know that each stream has a type.

You'll also notice that the trailing arrow(s) at the end of the diagrams indicate which types of streams are ultimately passed on at the end of a ConceptQL statement.

### What *are* Streams Really?

Though I think that a "stream" is a helpful abstraction when thinking in ConceptQL, on a few occasions we need to know what's going on under the hood.

Every table in the CDM structure has a surrogate key column (an ID column).  When we execute a ConceptQL statement, the "streams" that are generated by the statement are just sets of these IDs for rows that matched the ConceptQL criteria.  So each stream is just a set of IDs that point back to some rows in one of the CDM tables.  When a stream has a "type" it is really just that the stream contains IDs associated with its table of origin.

So when we execute this ConceptQL statement, the resulting "stream" is all the person IDs for all male patients in the database:


```YAML
---
- gender
- Male

```

![](spec/c82077b9455d0f9abc2c45ee1a298e38b99c9ce9cd685f65d87b376d7718d7ad.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 1 | 1 | person | 1923-05-01 | 1923-05-01 | 00013D2EFD8E45D1 |
| 2 | 2 | person | 1943-01-01 | 1943-01-01 | 00016F745862898F |
| 4 | 4 | person | 1941-06-01 | 1941-06-01 | 00021CA6FF03E670 |
| 5 | 5 | person | 1936-08-01 | 1936-08-01 | 00024B3D2352D2D0 |
| 6 | 6 | person | 1943-10-01 | 1943-10-01 | 0002DAE1C81CC70D |
| 7 | 7 | person | 1922-07-01 | 1922-07-01 | 0002F28CE057345B |
| 8 | 8 | person | 1935-09-01 | 1935-09-01 | 000308435E3E5B76 |
| 12 | 12 | person | 1929-06-01 | 1929-06-01 | 00048EF1F4791C68 |
| 14 | 14 | person | 1934-05-01 | 1934-05-01 | 00052705243EA128 |
| 16 | 16 | person | 1934-01-01 | 1934-01-01 | 0007E57CC13CE880 |

When we execute this ConceptQL statement, the resulting "stream" is all condition_occurrence IDs that match ICD-9 799.22:


```YAML
---
- icd9
- '799.22'

```

![](spec/05f9b844571ffceeed2def3025fb60c68552817b8b73d3c8a76939dbc08b7c65.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 273 | 33363 | condition_occurrence | 2010-06-17 | 2010-06-17 | 799.22 |
| 440 | 51450 | condition_occurrence | 2009-01-12 | 2009-01-12 | 799.22 |
| 1783 | 206904 | condition_occurrence | 2008-03-08 | 2008-03-08 | 799.22 |
| 1830 | 211909 | condition_occurrence | 2010-06-24 | 2010-06-24 | 799.22 |
| 2086 | 238625 | condition_occurrence | 2008-05-24 | 2008-05-24 | 799.22 |
| 2272 | 260093 | condition_occurrence | 2009-09-19 | 2009-09-19 | 799.22 |
| 2525 | 288414 | condition_occurrence | 2009-04-17 | 2009-04-17 | 799.22 |
| 2772 | 317847 | condition_occurrence | 2009-09-08 | 2009-09-08 | 799.22 |
| 2924 | 334949 | condition_occurrence | 2009-01-24 | 2009-01-24 | 799.22 |
| 4072 | 473603 | condition_occurrence | 2008-05-15 | 2008-05-15 | 799.22 |

Generally, I find it helpful to just think of those queries generating a "stream of people" or a "stream of conditions" and not worry about the table of origin or the fact that they are just IDs.

When a ConceptQL statement is executed, it yields a final set of streams that are just all the IDs that passed through all the criteria.  What is done with that set of IDs is up to the user who assembled the ConceptQL statement.  If a user gathers all 799.22 Conditions, they will end up with a set of condition_occurrence_ids.  They could take those IDs and do all sorts of things like:

- Gather the first and last date of occurrence per person
- Count the number of occurrences per person
- Count number of persons with the condition
- Count the total number of occurrences for the entire population

This kind of aggregation and analysis is beyond the scope of ConceptQL.  ConceptQL will get you the IDs of the rows you're interested in, its up to other parts of the calling system to determine what you do with them.

## Selection Operators

Selection operators are the parts of a ConceptQL query that search for specific values within the CDM data, e.g. searching the condition_occurrence table for a diagnosis of an old myocardial infarction (ICD-9 412) is a selection.  Selection operators are always leaf operators.

There are _many_ selection operators.  A list of currently implemented operators is available in Appendix A.

## All Other Operators i.e. Mutation Operators

Virtually all other operators add, remove, filter, or otherwise alter streams of results.  They are discussed in this section.

## Set Operators

Because streams represent sets of results, its makes sense to include a operators that operate on sets

### Union

- Takes any number of upstream operators and aggregates their streams
    - Unions together streams with identical types
        - Think of streams with the same type flowing together into a single stream
        - We're really just gathering the union of all IDs for identically-typed streams
    - Streams with the different types flow along together concurrently without interacting
        - It does not make sense to union, say, condition_occurrence_ids with visit_occurrence_ids, so streams with different types won't mingle together, but will continue to flow downstream in parallel


```YAML
---
- union
- - icd9
  - '412'
- - icd9
  - '799.22'

```

![](spec/ea935ac31f3b57ff373646780a1fba34a38c9e086dc771eb7fc16c65a7e20cfc.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |


```YAML
---
- union
- - union
  - - icd9
    - '412'
  - - icd9
    - '799.22'
- - place_of_service_code
  - '21'

```

![](spec/f766f2e3aa13420e3ba0f823ac7956b311ed7c6c20be26b72324fadd87f36712.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |


```YAML
---
- union
- - icd9
  - '412'
- - icd9
  - '799.22'
- - place_of_service_code
  - '21'

```

![](spec/a79274742cf6fac6f6c9f4a0eb651aeb452f9c43b537c8e6ccaefecd05b7105c.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |

### Intersect

1. Group incoming streams by type
1. For each group of same-type streams
     a. Intersect all streams, yielding a single stream that contains only those IDs common to those streams
1. A single stream for each incoming type is sent downstream
     a. If only a single stream of a type is upstream, that stream is essentially unaltered as it is passed downstream


```YAML
---
- intersect
- - icd9
  - '412'
- - primary_diagnosis
  - true

```

![](spec/af5ae3787e80bf0771f18f1a04fe4c5d9291e1e0f963ac408a7bc198d2f1ee28.png)

```No Results.  Statement is experimental.```


```YAML
---
- intersect
- - icd9
  - '412'
- - gender
  - Male

```

![](spec/514f263e976d07c0d9e0a86c79bcbdcddc7d444d7b72135294ad78758effd28f.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |


```YAML
---
- intersect
- - icd9
  - '412'
- - primary_diagnosis
  - true
- - gender
  - Male
- - race
  - White

```

![](spec/11f57941951bad5a75f9a16f38a31a3c6bf3046a475aac6e398e780892fab4ad.png)

```No Results.  Statement is experimental.```

### Complement

This operator will take the complement of each set of IDs in the incoming streams.


```YAML
---
- complement
- - icd9
  - '412'

```

![](spec/c2157d8a6b73abe4f22ba5042159f32502c74bf6d762be28d2df6831586822c7.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 1 | 1 | condition_occurrence | 2010-03-12 | 2010-03-13 | 780.2 |
| 1 | 2 | condition_occurrence | 2010-03-12 | 2010-03-13 | 788.20 |
| 1 | 3 | condition_occurrence | 2010-03-12 | 2010-03-13 | V45.01 |
| 1 | 4 | condition_occurrence | 2010-03-12 | 2010-03-13 | 428.0 |
| 1 | 5 | condition_occurrence | 2010-03-12 | 2010-03-13 | 272.0 |
| 1 | 6 | condition_occurrence | 2010-03-12 | 2010-03-13 | 401.9 |
| 1 | 7 | condition_occurrence | 2010-03-12 | 2010-03-13 | V45.02 |
| 1 | 8 | condition_occurrence | 2010-03-12 | 2010-03-13 | 733.00 |
| 1 | 9 | condition_occurrence | 2010-03-12 | 2010-03-13 | E933.0 |
| 1 | 10 | condition_occurrence | 2008-09-04 | 2008-09-04 | V58.41 |

If you're familiar with set operations, the complement of a union is the intersect of the complements of the items unioned.  So in our world, these next two examples are identical:


```YAML
---
- complement
- - union
  - - icd9
    - '412'
  - - primary_diagnosis
    - true

```

![](spec/02f44ad35d266ddd0a4df1691d26bf4a297b30604fc3f44b0391d6d852d23a9f.png)

```No Results.  Statement is experimental.```


```YAML
---
- intersect
- - complement
  - - icd9
    - '412'
- - complement
  - - primary_diagnosis
    - true

```

![](spec/a4450e8c0fe0e2fde92fe9bd61952f907b1976c1aa3ba963b809bed079d42b09.png)

```No Results.  Statement is experimental.```

But please be aware that this behavior of complement only affects streams of the same type.  If more than one stream is involved, you need to evaluate the effects of complement on a stream-by-stream basis:


```YAML
---
- complement
- - union
  - - icd9
    - '412'
  - - primary_diagnosis
    - true
  - - cpt
    - '99214'

```

![](spec/dbc66b3ae6bd7123d77dd04b64f8a24498d048725a55c5340b15f5ae0a1ff307.png)

```No Results.  Statement is experimental.```


```YAML
---
- intersect
- - complement
  - - icd9
    - '412'
- - complement
  - - primary_diagnosis
    - true
- - complement
  - - cpt
    - '99214'

```

![](spec/a9b4528726adec2a90f3f00139d8d0492f13c51f03c2f9ed6a5134b1b26b44a9.png)

```No Results.  Statement is experimental.```


```YAML
---
- union
- - intersect
  - - complement
    - - icd9
      - '412'
  - - complement
    - - primary_diagnosis
      - true
- - complement
  - - cpt
    - '99214'

```

![](spec/a4bc7382a1154ea9856544fd48418f3dd9ce474ca94b8859fc323749c6cc1f55.png)

```No Results.  Statement is experimental.```

### Except

This operator takes two sets of incoming streams, a left-hand stream and a right-hand stream.  The operator matches like-type streams between the left-hand and right-hand streams. The operator removes any results in the left-hand stream if they appear in the right-hand stream.  The operator passes only results for the left-hand stream downstream.  The operator discards all results in the right-hand stream. For example:


```YAML
---
- except
- :left:
  - icd9
  - '412'
  :right:
  - primary_diagnosis
  - true

```

![](spec/462153be527b28dc2cb5259c0aec62e1f529e8b60dc6e9c23fd1e06e8be933c9.png)

```No Results.  Statement is experimental.```


```YAML
---
- intersect
- - icd9
  - '412'
- - complement
  - - primary_diagnosis
    - true

```

![](spec/da450cdd0c94a1301bd98560339a45caa8041e09974352a56ecfb144e9a5e4d4.png)

```No Results.  Statement is experimental.```

If the left-hand stream has no types that match the right-hand stream, the left-hand stream passes through unaffected:


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

![](spec/253845fe6162621af407ebd110296ff4f6d8a3f23ec75dfb4ea8cda30be71262.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 6354 | 730080 | condition_occurrence | 2009-05-22 | 2009-05-22 | 412 |
| 405 | 47310 | condition_occurrence | 2010-04-21 | 2010-04-21 | 412 |
| 37067 | 4195911 | condition_occurrence | 2009-02-26 | 2009-02-26 | 412 |
| 31965 | 3622631 | condition_occurrence | 2008-05-09 | 2008-05-09 | 412 |
| 62025 | 6984372 | condition_occurrence | 2009-08-24 | 2009-08-24 | 412 |
| 7548 | 861875 | condition_occurrence | 2010-08-19 | 2010-09-08 | 412 |
| 72056 | 8102530 | condition_occurrence | 2008-02-14 | 2008-02-17 | 412 |
| 29548 | 3346625 | condition_occurrence | 2008-02-12 | 2008-02-19 | 412 |
| 51224 | 5768620 | condition_occurrence | 2010-04-21 | 2010-04-21 | 412 |
| 62051 | 6987562 | condition_occurrence | 2009-06-16 | 2009-06-16 | 412 |

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
  - - primary_diagnosis
    - true
  - - race
    - White

```

![](spec/f0c734b099841a754ae0366afb00e992ad4814479b65e4a7de23c6e3dd85c09a.png)

```No Results.  Statement is experimental.```

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
    - true

```

![](spec/1102fa717b1c2df67af5220bf3ae219afafd79be7bba0c117e301983385ada52.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 16 | 16 | death | 2010-12-01 | 2010-12-01 |  |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |

##### Q. Why aren't all streams passed forward unaltered?  Why union like-typed streams?

- The way Intersect works, if we passed like-typed streams forward without unioning them, Intersect would end up intersecting the two un-unioned like-type streams and that's not what we intended
- Essentially, these two diagrams would be identical:


```YAML
---
- intersect
- - union
  - - icd9
    - '412'
  - - icd9
    - '799.22'
- - cpt
  - '99214'

```

![](spec/d64993258ffbef9406d9ab9136de7af530626b3a69e9eeb75835e11f11dabf62.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |


```YAML
---
- intersect
- - intersect
  - - icd9
    - '412'
  - - icd9
    - '799.22'
- - cpt
  - '99214'

```

![](spec/defbd0b853d895802663f507761ad297d82e167f516c6082686a2a19b76012c5.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 2 | 48 | procedure_occurrence | 2009-07-03 | 2009-07-03 | 99214 |
| 2 | 95 | procedure_occurrence | 2009-12-02 | 2009-12-02 | 99214 |
| 5 | 118 | procedure_occurrence | 2008-12-14 | 2008-12-14 | 99214 |
| 5 | 134 | procedure_occurrence | 2009-12-21 | 2009-12-21 | 99214 |
| 5 | 144 | procedure_occurrence | 2009-07-04 | 2009-07-04 | 99214 |
| 6 | 167 | procedure_occurrence | 2009-09-12 | 2009-09-12 | 99214 |
| 6 | 176 | procedure_occurrence | 2010-02-23 | 2010-02-23 | 99214 |
| 7 | 291 | procedure_occurrence | 2009-09-27 | 2009-09-27 | 99214 |
| 7 | 350 | procedure_occurrence | 2010-05-23 | 2010-05-23 | 99214 |
| 7 | 357 | procedure_occurrence | 2008-09-21 | 2008-09-21 | 99214 |

## Time-oriented Operators

All results in a stream carry a start_date and end_date with them.  All temporal comparisons of streams use these two date columns.  Each result in a stream derives its start and end date from its corresponding row in its table of origin.

For instance, a visit_occurrence result derives its start_date from visit_start_date and its end_date from visit_end_date.

If a result comes from a table that only has a single date value, the result derives both its start_date and end_date from that single date, e.g. an observation result derives both its start_date and end_date from its corresponding row's observation_date.

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


```YAML
---
- occurrence
- 3
- - icd9
  - '412'

```

![](spec/328467a6a419c7c05e299b8097e5e000686068ded8dc6d5f2e2de6f51976c315.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 487 | 56319 | condition_occurrence | 2009-01-15 | 2009-01-19 | 412 |
| 506 | 59000 | condition_occurrence | 2010-07-19 | 2010-07-19 | 412 |
| 629 | 73033 | condition_occurrence | 2010-09-20 | 2010-09-20 | 412 |
| 985 | 114982 | condition_occurrence | 2009-09-29 | 2009-09-29 | 412 |
| 1336 | 156290 | condition_occurrence | 2009-10-03 | 2009-10-03 | 412 |
| 1779 | 206548 | condition_occurrence | 2010-02-09 | 2010-02-09 | 412 |
| 2475 | 282601 | condition_occurrence | 2009-02-28 | 2009-02-28 | 412 |
| 2529 | 289044 | condition_occurrence | 2010-07-18 | 2010-07-19 | 412 |
| 2942 | 337181 | condition_occurrence | 2010-01-22 | 2010-01-22 | 412 |
| 3206 | 365939 | condition_occurrence | 2009-03-25 | 2009-03-25 | 412 |

#### first

- Operator that is shorthand for writing "occurrence: 1"


```YAML
---
- first
- - icd9
  - '412'

```

![](spec/04491942fcbd741982514f9eb12aeecf3d54b5b69a2b50c8331f7700169d5521.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |
| 88 | 10443 | condition_occurrence | 2010-05-26 | 2010-05-26 | 412 |

#### last

- Operator that is just shorthand for writing "occurrence: -1"


```YAML
---
- last
- - icd9
  - '412'

```

![](spec/ebacbd092e3d1a3c7b745a381e51e8ff9d63a21db23a16940193e18e57bc866f.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 10196 | condition_occurrence | 2009-05-30 | 2009-05-30 | 412 |
| 88 | 10443 | condition_occurrence | 2010-05-26 | 2010-05-26 | 412 |

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

![](spec/ba90ef705f7be91c53c5eb4a81a439fa0f7c48532214bd3db3cc5c069160543e.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 88 | 10443 | condition_occurrence | 2010-05-26 | 2010-05-26 | 412 |
| 108 | 13741 | condition_occurrence | 2010-06-27 | 2010-06-27 | 412 |
| 149 | 17774 | condition_occurrence | 2010-11-22 | 2010-11-22 | 412 |
| 183 | 21619 | condition_occurrence | 2010-12-26 | 2010-12-26 | 412 |
| 206 | 24437 | condition_occurrence | 2010-02-07 | 2010-02-07 | 412 |
| 209 | 24989 | condition_occurrence | 2010-06-22 | 2010-06-23 | 412 |
| 231 | 28188 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 255 | 31542 | condition_occurrence | 2010-11-21 | 2010-11-21 | 412 |

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
  - payer
  - Part A

```

![](spec/ed039f82867241393b1a6a7153d3690461103934c72c1f3eaa3d99a12bb40885.png)

```No Results.  Statement is experimental.```

#### Edge behaviors

For 11 of the 13 temporal operators, comparison of results is straight-forward.  However, the before/after operators have a slight twist.

Imagine events 1-1-2-1-2-1.  In my mind, three 1's come before a 2 and two 1's come after a 2.  Accordingly:

- When comparing L **before** R, the temporal operator compares L against the **LAST** occurrence of R per person
- When comparing L **after** R, the temporal operator compares L against the **FIRST** occurrence of R per person

If we're looking for events in L that occur before events in R, then any event in L that occurs before the last event in R technically meet the comparison of "before".  The reverse is true for after: all events in L that occur after the first event in R technically occur after R.


```YAML
---
- before
- :left:
  - icd9
  - '412'
  :right:
  - icd9
  - '799.22'

```

![](spec/ee283d6a4b69cf10da2df703be3a16830be9cd8cd4f68c5f7afdf558ea28fa76.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 53785 | 6053034 | condition_occurrence | 2008-07-18 | 2008-07-18 | 412 |
| 4289 | 496274 | condition_occurrence | 2008-07-19 | 2008-07-19 | 412 |
| 103062 | 11580605 | condition_occurrence | 2008-08-28 | 2008-08-28 | 412 |
| 12524 | 1422629 | condition_occurrence | 2009-08-25 | 2009-08-25 | 412 |
| 20306 | 2302248 | condition_occurrence | 2010-01-04 | 2010-01-04 | 412 |
| 81188 | 9131971 | condition_occurrence | 2010-02-15 | 2010-02-15 | 412 |
| 81188 | 9132070 | condition_occurrence | 2009-11-07 | 2009-11-07 | 412 |
| 97169 | 10930462 | condition_occurrence | 2008-02-05 | 2008-02-05 | 412 |
| 98040 | 11029333 | condition_occurrence | 2008-10-02 | 2008-10-02 | 412 |
| 98040 | 11029388 | condition_occurrence | 2008-08-09 | 2008-08-09 | 412 |

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
    - '799.22'

```

![](spec/de589af36fa854e006a1563c93e644e2210f2a5616babb779f7f38aadb6c1ed7.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 53785 | 6053034 | condition_occurrence | 2008-07-18 | 2008-07-18 | 412 |
| 4289 | 496274 | condition_occurrence | 2008-07-19 | 2008-07-19 | 412 |
| 103062 | 11580605 | condition_occurrence | 2008-08-28 | 2008-08-28 | 412 |
| 12524 | 1422629 | condition_occurrence | 2009-08-25 | 2009-08-25 | 412 |
| 20306 | 2302248 | condition_occurrence | 2010-01-04 | 2010-01-04 | 412 |
| 81188 | 9131971 | condition_occurrence | 2010-02-15 | 2010-02-15 | 412 |
| 81188 | 9132070 | condition_occurrence | 2009-11-07 | 2009-11-07 | 412 |
| 97169 | 10930462 | condition_occurrence | 2008-02-05 | 2008-02-05 | 412 |
| 98040 | 11029333 | condition_occurrence | 2008-10-02 | 2008-10-02 | 412 |
| 98040 | 11029388 | condition_occurrence | 2008-08-09 | 2008-08-09 | 412 |

### Time Windows

There are situations when the date columns associated with a result should have their values shifted forward or backward in time to make a comparison with another set of dates.

#### time_window

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


```YAML
---
- during
- :left:
  - icd9
  - '799.22'
  :right:
  - time_window
  - - icd9
    - '412'
  - :start: "-30d"
    :end: 30d

```

![](spec/8101d9b89d9ba8070d585432707b43a8acdb4c2a3e9d37c3f7114b5e3ea9e800.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 2086 | 238625 | condition_occurrence | 2008-05-24 | 2008-05-24 | 799.22 |
| 5121 | 590274 | condition_occurrence | 2009-03-26 | 2009-04-04 | 799.22 |
| 11427 | 1298251 | condition_occurrence | 2008-09-06 | 2008-09-06 | 799.22 |
| 16432 | 1870381 | condition_occurrence | 2009-02-16 | 2009-02-16 | 799.22 |
| 37733 | 4272148 | condition_occurrence | 2010-03-09 | 2010-03-09 | 799.22 |
| 54141 | 6093274 | condition_occurrence | 2010-06-13 | 2010-06-13 | 799.22 |
| 110498 | 12420479 | condition_occurrence | 2009-04-30 | 2009-04-30 | 799.22 |


```YAML
---
- time_window
- - icd9
  - '412'
- :start: "-2y"
  :end: "-2y"

```

![](spec/15268bc45993d3f57ccf915877f91e48bdee684f24faa614249915833cac4af9.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2006-08-25 | 2006-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2007-04-30 | 2007-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2008-02-12 | 2008-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2006-06-05 | 2006-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2007-07-19 | 2007-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2007-07-25 | 2007-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2006-11-16 | 2006-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2008-10-06 | 2008-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2007-01-28 | 2007-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2007-01-03 | 2007-01-09 | 412 |


```YAML
---
- time_window
- - icd9
  - '412'
- :start: "-2m-2d"
  :end: 3d1y

```

![](spec/cc960a268d51ccf2ebde657d36848f780213834844900018bce3d111843f7b0f.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-06-23 | 2009-08-28 | 412 |
| 17 | 1829 | condition_occurrence | 2009-02-26 | 2010-05-03 | 412 |
| 37 | 4359 | condition_occurrence | 2009-12-10 | 2011-02-15 | 412 |
| 53 | 5751 | condition_occurrence | 2008-04-03 | 2009-06-08 | 412 |
| 59 | 6083 | condition_occurrence | 2009-05-17 | 2010-07-25 | 412 |
| 64 | 6902 | condition_occurrence | 2009-05-23 | 2010-07-28 | 412 |
| 71 | 7865 | condition_occurrence | 2008-09-14 | 2009-11-19 | 412 |
| 75 | 8397 | condition_occurrence | 2010-08-04 | 2011-10-09 | 412 |
| 79 | 8618 | condition_occurrence | 2008-11-26 | 2010-02-02 | 412 |
| 86 | 9882 | condition_occurrence | 2008-11-01 | 2010-01-12 | 412 |


```YAML
---
- time_window
- - place_of_service_code
  - '21'
- :start: ''
  :end: start

```

![](spec/886bf85249a704668a55c5161bceaac10be4a41a94b91606f49851dfa017526c.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 1 | 1 | visit_occurrence | 2010-03-12 | 2010-03-12 | Inpatient |
| 2 | 8 | visit_occurrence | 2009-09-17 | 2009-09-17 | Inpatient |
| 2 | 9 | visit_occurrence | 2009-04-12 | 2009-04-12 | Inpatient |
| 2 | 10 | visit_occurrence | 2010-06-26 | 2010-06-26 | Inpatient |
| 2 | 11 | visit_occurrence | 2009-08-31 | 2009-08-31 | Inpatient |
| 14 | 507 | visit_occurrence | 2008-09-12 | 2008-09-12 | Inpatient |
| 17 | 729 | visit_occurrence | 2010-05-22 | 2010-05-22 | Inpatient |
| 17 | 730 | visit_occurrence | 2008-09-19 | 2008-09-19 | Inpatient |
| 17 | 731 | visit_occurrence | 2010-06-02 | 2010-06-02 | Inpatient |
| 17 | 732 | visit_occurrence | 2010-06-16 | 2010-06-16 | Inpatient |


```YAML
---
- time_window
- - icd9
  - '412'
- :start: end
  :end: start

```

![](spec/6705af65d728c0d5c50d6c4d46253017a91eb459dbb1f40f92449f05d5562f4a.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-22 | 2009-07-19 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-30 | 2009-01-28 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-09 | 2009-01-03 | 412 |

#### Temporal Operators and Person Streams

Person streams carry a patient's date of birth in their date columns.  This makes them almost useless when they are part of the L stream of a temporal operator.  But person streams are useful as the R stream.  By ```time_window```ing the patient's date of birth, we can filter based on the patient's age like so:


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

![](spec/68fac940a32c7e40caacf8e560c61da552d57633d015ba98f2e98ec040a00c5b.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 92077 | 10363643 | condition_occurrence | 2010-03-08 | 2010-03-08 | 412 |
| 66609 | 7497031 | condition_occurrence | 2009-05-25 | 2009-05-28 | 412 |
| 13729 | 1563187 | condition_occurrence | 2008-06-13 | 2008-06-13 | 412 |
| 10876 | 1237925 | condition_occurrence | 2008-09-13 | 2008-09-13 | 412 |
| 10876 | 1237830 | condition_occurrence | 2008-02-02 | 2008-02-03 | 412 |
| 54683 | 6153652 | condition_occurrence | 2008-10-24 | 2008-10-28 | 412 |
| 16106 | 1833669 | condition_occurrence | 2009-07-06 | 2009-07-13 | 412 |
| 68518 | 7706073 | condition_occurrence | 2009-02-22 | 2009-02-22 | 412 |
| 52736 | 5937885 | condition_occurrence | 2008-05-07 | 2008-05-07 | 412 |
| 62215 | 7004785 | condition_occurrence | 2008-06-10 | 2008-06-10 | 412 |

## Type Conversion

There are situations where it is appropriate to convert the type of a stream of results into a different type.  In programmer parlance, we say "typecasting" or "casting", which is the terminology we'll use here.  A good analogy and mnemonic for casting is to think of taking a piece of metal, say a candle holder, melting it down, and recasting it into, say, a lamp.  We'll do something similar with streams.  We'll take, for example, a visit_occurrence stream and recast it into a stream of person.

### Casting to person

- Useful if we're just checking for the presence of a condition for a person
- E.g. We want to know *if* a person has an old MI, not when an MI or how many MIs occurred


```YAML
---
- person
- - icd9
  - '412'

```

![](spec/8ed478d8c81a58a202d0c51348fca246df206fc24a0567b163d4e0bdab56ca46.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 251 | 251 | person | 1928-10-01 | 1928-10-01 | 008645209D3E025E |
| 66532 | 66532 | person | 1943-04-01 | 1943-04-01 | 96AB8ADC5FA7AD8C |
| 64221 | 64221 | person | 1934-04-01 | 1934-04-01 | 916F76F7FDF6B6CF |
| 111839 | 111839 | person | 1938-12-01 | 1938-12-01 | FDE56ED4546D17F6 |
| 25643 | 25643 | person | 1916-06-01 | 1916-06-01 | 39BA7D25EC6D1B14 |
| 79317 | 79317 | person | 1943-02-01 | 1943-02-01 | B441BDCB76C7C267 |
| 108128 | 108128 | person | 1935-02-01 | 1935-02-01 | F58409ED69652B4A |
| 77900 | 77900 | person | 1934-05-01 | 1934-05-01 | B0E710725FE3FE97 |
| 61145 | 61145 | person | 1942-07-01 | 1942-07-01 | 8A595528CF5E2859 |
| 18149 | 18149 | person | 1946-09-01 | 1946-09-01 | 28AFD67E63039098 |

### Casting to a visit_occurrence

- It is common to look for a set of conditions that coincide with a set of procedures
- Gathering conditions yields a condition stream, gathering procedures yields a procedure stream
    - It is not possible to compare those two streams directly using AND
    - It is possible to compare the streams temporally, but CDM provides a visit_occurrence table to explicitly tie a set of conditions to a set of procedures
- Casting both streams to visit_occurrence streams allows us to gather all visit_occurrences for which a set of conditions/procedures occurred in the same visit


```YAML
---
- intersect
- - visit_occurrence
  - - icd9
    - '412'
- - visit_occurrence
  - - cpt
    - '99214'

```

![](spec/62323426e381ec21c967971a67e1f4a6d89dae92154bd937284e00b67f67fdd3.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 59633 | 2958903 | visit_occurrence | 2010-07-08 | 2010-07-08 | Office |
| 8462 | 423786 | visit_occurrence | 2008-08-24 | 2008-08-24 | Office |
| 48614 | 2410554 | visit_occurrence | 2009-06-05 | 2009-06-05 | Office |
| 92639 | 4587768 | visit_occurrence | 2009-04-25 | 2009-04-25 | Office |
| 46156 | 2292353 | visit_occurrence | 2008-06-18 | 2008-06-18 | Office |
| 105614 | 5223564 | visit_occurrence | 2008-02-03 | 2008-02-03 | Office |
| 21343 | 1061266 | visit_occurrence | 2008-04-25 | 2008-04-25 | Office |
| 62315 | 3086112 | visit_occurrence | 2008-05-27 | 2008-05-27 | Office |
| 18286 | 914814 | visit_occurrence | 2010-02-10 | 2010-02-10 | Office |
| 27340 | 1365178 | visit_occurrence | 2009-06-17 | 2009-06-17 | Office |

Many tables have a foreign key (FK) reference to the visit_occurrence table.  If we cast a result to a visit_occurrence, and its table of origin has a visit_occurrence_id FK column, the result becomes a visit_occurrence result corresponding to the row pointed to by visit_occurrence_id.  If the row's visit_occurrence_id is NULL, the result is discarded from the stream.

If the result's table of origin has no visit_occurrence_id column, we will instead replace the result with ALL visit_occurrences for the person assigned to the result.  This allows us to convert between a person stream and visit_occurrence stream and back.  E.g. we can get all male patients, then ask for their visit_occurrences later downstream.


```YAML
---
- visit_occurrence
- - gender
  - Male

```

![](spec/e8630103287f7c9d28eff40b3b1826e24846e776b877f7b8554257acbe621e1c.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 10295 | 516092 | visit_occurrence | 2008-04-08 | 2008-04-08 | Outpatient |
| 10295 | 516093 | visit_occurrence | 2008-07-28 | 2008-07-28 | Outpatient |
| 10295 | 516094 | visit_occurrence | 2009-05-27 | 2009-05-27 | Outpatient |
| 10295 | 516095 | visit_occurrence | 2008-09-03 | 2008-09-03 | Outpatient |
| 10295 | 516096 | visit_occurrence | 2008-05-31 | 2008-05-31 | Outpatient |
| 10295 | 516097 | visit_occurrence | 2008-09-13 | 2008-09-13 | Outpatient |
| 10295 | 516098 | visit_occurrence | 2008-08-23 | 2008-08-23 | Outpatient |
| 10295 | 516099 | visit_occurrence | 2008-04-28 | 2008-04-28 | Office |
| 10295 | 516100 | visit_occurrence | 2009-03-26 | 2009-03-26 | Office |
| 10295 | 516101 | visit_occurrence | 2009-09-22 | 2009-09-22 | Office |

### Casting Loses All Original Information

After a result undergoes casting, it loses its original information.  E.g. casting a visit_occurrence to a person loses the visit_occurrence information and resets the start_date and end_date columns to the person's date of birth.  As a side note, this is actually handy if a stream’s dates have been altered by a time_window operator and you want the original dates later on.  Just cast the stream to its same type and it will regain its original dates.

### Cast all the Things!

Although casting to visit_occurrence and person are the most common types of casting, we can cast to and from any of the types in the ConceptQL system.

The general rule will be that if the source type has a defined relationship with the target type, we'll cast using that relationship, e.g. casting visit_occurrences to procedures will turn all visit_occurrence results into the set of procedure results that point at those original visit_occurrences.  But if there is no direct relationship, we'll do a generous casting, e.g. casting observations to procedures will return all procedures for all persons in the observation stream.

INSERT HANDY TABLE SHOWING CONVERSION MATRIX HERE


```YAML
---
- procedure_cost
- - intersect
  - - cpt
    - '70012'
  - - procedure
    - - intersect
      - - place_of_service_code
        - '21'
      - - visit_occurrence
        - - icd9
          - '412'

```

![](spec/6a34c0ef589c9c976fe41f3e67e799e198499f5b9c3ebfd240fb91f73e893573.png)

```No Results.  Statement is experimental.```

### Casting as a way to fetch all rows

The casting operator doubles as a way to fetch all rows for a single type.  Provide the casting operator with an argument of ```true``` (instead of an upstream operator) to get all rows as results:


```YAML
---
- death
- true

```

![](spec/e9b384fa7dec5f1a06479c4b289e06b1e60e4f23f7630aff6d03c52595f500f8.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 16 | 16 | death | 2010-12-01 | 2010-12-01 |  |
| 177 | 177 | death | 2010-07-01 | 2010-07-01 |  |
| 293 | 293 | death | 2010-01-01 | 2010-01-01 |  |
| 306 | 306 | death | 2010-05-01 | 2010-05-01 |  |
| 375 | 375 | death | 2010-03-01 | 2010-03-01 |  |
| 429 | 429 | death | 2010-03-01 | 2010-03-01 |  |
| 450 | 450 | death | 2010-11-01 | 2010-11-01 |  |
| 555 | 555 | death | 2010-11-01 | 2010-11-01 |  |
| 565 | 565 | death | 2010-06-01 | 2010-06-01 |  |
| 603 | 603 | death | 2010-06-01 | 2010-06-01 |  |

This comes in handy for situations like these:


```YAML
---
- person_filter
- :left:
  - gender
  - Male
  :right:
  - death
  - true

```

![](spec/58113a57a37431a402d2547369eba3a481bf1dbbfd82dc384406a5c91f6df01f.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 55510 | 55510 | person | 1930-08-01 | 1930-08-01 | 7D34060FA1EF58C6 |
| 74808 | 74808 | person | 1927-02-01 | 1927-02-01 | A9BE60D395FEE13D |
| 32780 | 32780 | person | 1961-09-01 | 1961-09-01 | 49BF11D11CEF2328 |
| 87909 | 87909 | person | 1934-04-01 | 1934-04-01 | C7727009E7DDF6B8 |
| 43890 | 43890 | person | 1920-03-01 | 1920-03-01 | 6309F87AE1E03227 |
| 46052 | 46052 | person | 1941-09-01 | 1941-09-01 | 67D8035124FE474E |
| 88540 | 88540 | person | 1952-08-01 | 1952-08-01 | C8E882134C354ADF |
| 10616 | 10616 | person | 1946-07-01 | 1946-07-01 | 179C0EDEB061D6E3 |
| 74892 | 74892 | person | 1927-02-01 | 1927-02-01 | A9F0108311BE3424 |
| 84318 | 84318 | person | 1938-06-01 | 1938-06-01 | BF7387DC991F39A9 |

## Filtering by People

Often we want to filter out a set of results by people.  For instance, say we wanted to find all MIs for all males.  We'd use the person_filter operator for that.  Like the Except operator, it takes a left-hand stream and a right-hand stream.

Unlike the ```except``` operator, the person_filter operator will use all types of all streams in the right-hand side to filter out results in all types of all streams on the left hand side.


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

![](spec/0360fc0c2b7a88fd82ffc4d13387b76766649d5d42aa8f9349bbf60a81ac6119.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 92077 | 10363643 | condition_occurrence | 2010-03-08 | 2010-03-08 | 412 |
| 66609 | 7497031 | condition_occurrence | 2009-05-25 | 2009-05-28 | 412 |
| 13729 | 1563187 | condition_occurrence | 2008-06-13 | 2008-06-13 | 412 |
| 10876 | 1237925 | condition_occurrence | 2008-09-13 | 2008-09-13 | 412 |
| 10876 | 1237830 | condition_occurrence | 2008-02-02 | 2008-02-03 | 412 |
| 54683 | 6153652 | condition_occurrence | 2008-10-24 | 2008-10-28 | 412 |
| 16106 | 1833669 | condition_occurrence | 2009-07-06 | 2009-07-13 | 412 |
| 33793 | 3829115 | condition_occurrence | 2008-01-17 | 2008-01-21 | 412 |
| 68518 | 7706073 | condition_occurrence | 2009-02-22 | 2009-02-22 | 412 |
| 52736 | 5937885 | condition_occurrence | 2008-05-07 | 2008-05-07 | 412 |

But we can get crazier.  The right-hand side doesn't have to be a person stream.  If a non-person stream is used in the right-hand side, the person_filter will cast all right-hand streams to person first and use the union of those streams:


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

![](spec/26fd52b5ac55438dd9f81b4a3f3913f1058c9f225c8a5e129007c1e9413d5881.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 92077 | 10363643 | condition_occurrence | 2010-03-08 | 2010-03-08 | 412 |
| 108031 | 12142323 | condition_occurrence | 2009-11-25 | 2009-11-25 | 412 |
| 56414 | 6351863 | condition_occurrence | 2008-11-15 | 2008-11-15 | 412 |
| 66609 | 7497031 | condition_occurrence | 2009-05-25 | 2009-05-28 | 412 |
| 10876 | 1237830 | condition_occurrence | 2008-02-02 | 2008-02-03 | 412 |
| 10876 | 1237925 | condition_occurrence | 2008-09-13 | 2008-09-13 | 412 |
| 33463 | 3787772 | condition_occurrence | 2009-08-08 | 2009-08-08 | 412 |
| 48678 | 5484541 | condition_occurrence | 2009-09-09 | 2009-09-09 | 412 |
| 54683 | 6153652 | condition_occurrence | 2008-10-24 | 2008-10-28 | 412 |
| 68518 | 7706073 | condition_occurrence | 2009-02-22 | 2009-02-22 | 412 |


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

![](spec/e1cb0863b21e14256d61a54200316791f6547c78ba2f0156c110f4500f9bbd49.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 92077 | 10363643 | condition_occurrence | 2010-03-08 | 2010-03-08 | 412 |
| 108031 | 12142323 | condition_occurrence | 2009-11-25 | 2009-11-25 | 412 |
| 56414 | 6351863 | condition_occurrence | 2008-11-15 | 2008-11-15 | 412 |
| 66609 | 7497031 | condition_occurrence | 2009-05-25 | 2009-05-28 | 412 |
| 10876 | 1237830 | condition_occurrence | 2008-02-02 | 2008-02-03 | 412 |
| 10876 | 1237925 | condition_occurrence | 2008-09-13 | 2008-09-13 | 412 |
| 33463 | 3787772 | condition_occurrence | 2009-08-08 | 2009-08-08 | 412 |
| 48678 | 5484541 | condition_occurrence | 2009-09-09 | 2009-09-09 | 412 |
| 54683 | 6153652 | condition_occurrence | 2008-10-24 | 2008-10-28 | 412 |
| 68518 | 7706073 | condition_occurrence | 2009-02-22 | 2009-02-22 | 412 |


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

![](spec/5d331d74c460d75814b2d3138a9b7d90b5ddb2dcd85e1f5f260d183745fc3a1e.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |

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

![](spec/c93dd18894a245a5647f99e1867d3779e4cd34c9c8f8860600ff0c837a5ffa53.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 91 | 10865 | condition_occurrence | 2009-11-08 | 2009-11-08 | 412 |
| 108 | 13741 | condition_occurrence | 2010-06-27 | 2010-06-27 | 412 |
| 128 | 15149 | condition_occurrence | 2008-03-22 | 2008-03-23 | 412 |
| 146 | 17041 | condition_occurrence | 2008-04-07 | 2008-04-07 | 412 |
| 149 | 17772 | condition_occurrence | 2008-08-16 | 2008-08-16 | 412 |
| 149 | 17774 | condition_occurrence | 2010-11-22 | 2010-11-22 | 412 |
| 158 | 18412 | condition_occurrence | 2009-10-25 | 2009-10-29 | 412 |
| 183 | 21619 | condition_occurrence | 2010-12-26 | 2010-12-26 | 412 |

## Sub-algorithms within a Larger Algorithm

If a algorithm is particularly complex, or has a stream of results that are used more than once, it can be helpful to break the algorithm into a set of sub-algorithms.  This can be done using the `label` options and the `recall` operator.

### `label` option

Any ConceptQL operator can be assigned a label.  The label simply provides a way to apply a brief description to an operator, generally, what kind of results the operator is producing.  Any operator that has a label can be accessed via the `recall` operator.

### `recall` operator

- Takes 1 argument
    - The "label" of an operator from which you'd like to pull the exact same set of results

A stream must be `define`d before `recall` can use it.


```YAML
---
- first
- - union
  - - intersect
    - - visit_occurrence
      - - icd9
        - '412'
      - :label: Heart Attack Visit
    - - place_of_service_code
      - '21'
  - - before
    - :left:
      - intersect
      - - recall
        - Heart Attack Visit
      - - complement
        - - place_of_service_code
          - 21
      - :label: Outpatient Heart Attack
      :right:
      - time_window
      - - recall
        - Outpatient Heart Attack
      - :start: "-30d"
        :end: '0'
      :label: Earliest of Two Outpatient Heart Attacks

```

![](spec/4a3b47ed1c54f96ebdae693d41c36c51884c4546ef799a4108085708fb7b964e.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 59 | 2705 | visit_occurrence | 2009-07-19 | 2009-07-22 | Inpatient |
| 79 | 3847 | visit_occurrence | 2009-01-28 | 2009-01-30 | Inpatient |
| 86 | 4378 | visit_occurrence | 2009-01-03 | 2009-01-09 | Inpatient |
| 128 | 6640 | visit_occurrence | 2008-03-22 | 2008-03-23 | Inpatient |
| 158 | 8108 | visit_occurrence | 2009-10-25 | 2009-10-29 | Inpatient |
| 173 | 8806 | visit_occurrence | 2009-06-13 | 2009-06-16 | Inpatient |
| 222 | 11783 | visit_occurrence | 2008-03-14 | 2008-03-21 | Inpatient |
| 260 | 13972 | visit_occurrence | 2010-05-29 | 2010-06-21 | Inpatient |
| 352 | 18458 | visit_occurrence | 2008-07-02 | 2008-07-09 | Inpatient |
| 407 | 20925 | visit_occurrence | 2008-08-25 | 2008-08-27 | Inpatient |

## Algorithms within Algorithms

One of the main motivations behind keeping ConceptQL so flexible is to allow users to build ConceptQL statements from other ConceptQL statements.  This section loosely describes how this feature will work.  Its actual execution and implementation will differ from what is presented here.

Say a ConceptQL statement gathers all visit_occurrences where a patient had an MI and a Hospital encounter (CPT 99231):


```YAML
---
- intersect
- - visit_occurrence
  - - icd9
    - '412'
- - visit_occurrence
  - - cpt
    - '99231'

```

![](spec/5d6ff62038b75d6f240d65f35d1520a131c221f47d3801554c8c2be5d528ebb0.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 108335 | 5357904 | visit_occurrence | 2009-12-07 | 2009-12-07 | Office |
| 23251 | 1158016 | visit_occurrence | 2009-07-24 | 2009-07-24 | Office |
| 13270 | 662308 | visit_occurrence | 2010-07-23 | 2010-07-25 | Office |
| 24119 | 1199980 | visit_occurrence | 2008-11-30 | 2008-12-05 | Office |
| 91102 | 4511328 | visit_occurrence | 2008-09-01 | 2008-09-01 | Office |
| 3646 | 184096 | visit_occurrence | 2009-01-09 | 2009-01-09 | Office |
| 21338 | 1061186 | visit_occurrence | 2008-07-11 | 2008-07-11 | Office |
| 86004 | 4256504 | visit_occurrence | 2008-04-18 | 2008-04-18 | Office |
| 112447 | 5561049 | visit_occurrence | 2008-12-22 | 2008-12-25 | Office |
| 20229 | 1009400 | visit_occurrence | 2008-09-06 | 2008-09-06 | Office |

If we wanted to gather all costs for all procedures for those visits, we could use the "algorithm" operator to represent the algorithm defined above in a new concept:


```YAML
---
- procedure_cost
- - algorithm
  - |2-

    All Visits
    where a Patient had
    both an MI and
    a Hospital Encounter

```

![](spec/eb8f5511f7d88bd0f8ba73420fc10f7c78405db7f4373d778a827058707f888e.png)

```No Results.  Statement is experimental.```

The color and edge coming from the algorithm operator are black to denote that we don't know what types or streams are coming from the concept.  In reality, any program that uses ConceptQL can ask the algorithm represented by the algorithm operator for the concept's types.  The result of nesting one algorithm within another is exactly the same had we taken algorithm operator and replaced it with the ConceptQL statement for the algorithm it represents.


```YAML
---
- procedure_cost
- - intersect
  - - visit_occurrence
    - - icd9
      - '412'
  - - visit_occurrence
    - - cpt
      - '99231'

```

![](spec/6b48534236697d1ccfa1f5403764782f9d228f9eb706789cfa80203882b7b13a.png)

```No Results.  Statement is experimental.```

In the actual implementation of the algorithm operator, each ConceptQL statement will have a unique identifier which the algorithm operator will use.  So, assuming that the ID 2031 represents the algorithm we want to gather all procedure costs for, our example should really read:


```YAML
---
- procedure_cost
- - algorithm
  - 2031

```

![](spec/067241a3579767a802d4f8e20fd35b60adbe377c9a6512ef135f164a5accfb27.png)

```No Results.  Statement is experimental.```

## Values

A result can carry forward three different types of values, modeled after the behavior of the observation table:

- value_as_numeric
    - For values like lab values, counts of occurrence of results, cost information
- value_as_string
    - For value_as_string from observation table, or notes captured in EHR data
- value_as_concept_id
    - For values that are like factors from the observation value_as_concept_id column

By default, all value fields are set to NULL, unless a selection operator is explicitly written to populate one or more of those fields.

There are many operations that can be performed on the value_as\_\* columns and as those operations are implemented, this section will grow.

For now we'll cover some of the general behavior of the value_as_numeric column and it's associated operators.

### numeric

- Takes 2 arguments
    - A stream
    - And a numeric value or a symbol representing the name of a column in CDM

Passing streams through a `numeric` operator changes the number stored in the value column:


```YAML
---
- numeric
- 2
- - icd9
  - '412'

```

![](spec/d39452b58257c95a7cba07afed4877417b0c227f3690e2bff22c9eca89eac845.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |

`numeric` can also take a column name instead of a number.  It will derive the results row's value from the value stored in the column specified.


```YAML
---
- numeric
- paid_copay
- - procedure_cost
  - - cpt
    - '99214'

```

![](spec/3f46dee4d775d1a29d52b68af6552f8ea3abd8303094e749714fc77bd7958155.png)

```No Results.  Statement is experimental.```

If something nonsensical happens, like the column specified isn't present in the table pointed to by a result row, value_as_numeric in the result row will be unaffected:


```YAML
---
- value
- paid_copay
- - icd9
  - '412'

```

![](spec/2b57886a9cba66bb696e4b399c51ad0dc95cd64b952709fafc819a79d573f09e.png)

```No Results.  Statement is experimental.```

Or if the column specified exists, but refers to a non-numerical column, we'll set the value to 0


```YAML
---
- value
- stop_reason
- - icd9
  - '412'

```

![](spec/7b9db2986ab9ada45cfb9451ef87ff1a2d99c908083334b7ccdceb8a92387fa9.png)

```No Results.  Statement is experimental.```

With a `numeric` operator defined, we could introduce a sum operator that will sum by patient and type.  This allows us to implement the Charlson comorbidity algorithm:


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

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 20485 | 0 | person | 1939-04-01 | 1939-04-01 | 2DDD007275DD21E0 |
| 79028 | 0 | person | 1959-02-01 | 1959-02-01 | B392FC430DF921CD |
| 100859 | 0 | person | 1956-05-01 | 1956-05-01 | E52898242C537BA0 |
| 14065 | 0 | person | 1946-11-01 | 1946-11-01 | 1F60AFE3D4FBB0F8 |
| 19728 | 0 | person | 1929-03-01 | 1929-03-01 | 2C18DC0853458E88 |
| 6249 | 0 | person | 1941-03-01 | 1941-03-01 | 0DD88DF606E34410 |
| 81868 | 0 | person | 1942-09-01 | 1942-09-01 | BA17E53F3EB2C999 |
| 111550 | 0 | person | 1943-06-01 | 1943-06-01 | FD35C56E74BFB4AB |
| 93771 | 0 | person | 1941-01-01 | 1941-01-01 | D4BF3A123E98674C |
| 92853 | 0 | person | 1932-06-01 | 1932-06-01 | D2945588C9CE4481 |

### Counting

It might be helpful to count the number of occurrences of a result row in a stream.  A simple "count" operator could group identical rows and store the number of occurrences in the value_as_numeric column.

I need examples of algorithms that could benefit from this operator.  I'm concerned that we'll want to roll up occurrences by person most of the time and that would require us to first cast streams to person before passing the person stream to count.


```YAML
---
- count
- - person
  - - icd9
    - '799.22'

```

![](spec/ff7d5b5573d09bd7c4cdd3aeda124d18bf82ec46673a62881b399a75d69f3f53.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 84506 | 84506 | person | 1946-11-01 | 1946-11-01 | BFD9934105A902C5 |
| 8511 | 8511 | person | 1934-02-01 | 1934-02-01 | 12F9E8CFD305414D |
| 58597 | 58597 | person | 1922-11-01 | 1922-11-01 | 84841824E5D1516F |
| 17481 | 17481 | person | 1952-04-01 | 1952-04-01 | 272C688CA4CFC78F |
| 79930 | 79930 | person | 1940-04-01 | 1940-04-01 | B5AA192186CEFC33 |
| 83321 | 83321 | person | 1928-06-01 | 1928-06-01 | BD49BED9C6228FA1 |
| 111134 | 111134 | person | 1960-05-01 | 1960-05-01 | FC4C2599EA86941A |
| 112745 | 112745 | person | 1959-07-01 | 1959-07-01 | FFFA950301FCA748 |
| 11368 | 11368 | person | 1955-08-01 | 1955-08-01 | 19546CD71F65766E |
| 24243 | 24243 | person | 1930-01-01 | 1930-01-01 | 3695943370154829 |

We could do dumb things like count the number of times a row shows up in a union:


```YAML
---
- count
- - union
  - - icd9
    - '412'
  - - primary_diagnosis
    - true

```

![](spec/7aa76b4d29874719466c2cbafc9936e9f12e504bf31e1a09d26ca3fffa8ba1a6.png)

```No Results.  Statement is experimental.```

#### Numeric Value Comparison

Acts like any other binary operator.  L and R streams, joined by person.  Any L that pass comparison go downstream.  R is thrown out.  Comparison based on result row's value column.

- Less than
- Less than or equal
- Equal
- Greater than or equal
- Greater than
- Not equal

### numeric as selection operator

Numeric doesn't have to take a stream.  If it doesn't have a stream as an argument, it acts like a selection operator much like date_range


```YAML
---
- greater_than
- :left:
  - count
  - - person
    - - icd9
      - '412'
  :right:
  - numeric
  - 1

```

![](spec/c1d0402862221d85aceedc7d76b3f82149b612cbd972f14d0ca9011e1e2c455c.png)

```No Results.  Statement is experimental.```

#### sum

- Takes a stream of results and does some wild things
    - Groups all results by person and type
        - Sums the value_as_numeric column within that grouping
        - Sets start_date to the earliest start_date in the group
        - Sets the end_date to the most recent end_date in the group
        - Sets selection_id to 0 since there is no particular single row that the result refers to anymore

## Appendix A - Selection Operators

| Operator Name | Stream Type | Arguments | Returns |
| ---- | ---- | --------- | ------- |
| cpt  | procedure_occurrence | 1 or more CPT codes | All results whose source_value match any of the CPT codes |
| icd9 | condition_occurrence | 1 or more ICD-9 codes | All results whose source_value match any of the ICD-9 codes |
| icd9_procedure | procedure_occurrence | 1 or more ICD-9 procedure codes | All results whose source_value match any of the ICD-9 procedure codes |
| icd10 | condition_occurrence | 1 or more ICD-10 | All results whose source_value match any of the ICD-10 codes |
| hcpcs  | procedure_occurrence | 1 or more HCPCS codes | All results whose source_value match any of the HCPCS codes |
| gender | person | 1 or more gender concept_ids | All results whose gender_concept_id match any of the concept_ids|
| loinc | observation | 1 or more LOINC codes | All results whose source_value match any of the LOINC codes |
| place_of_service_code | visit_occurrence | 1 or more place of service codes | All results whose place of service matches any of the codes|
| race | person | 1 or more race concept_ids | All results whose race_concept_id match any of the concept_ids|
| rxnorm | drug_exposure | 1 or more RxNorm IDs | All results whose drug_concept_id match any of the RxNorm IDs|
| snomed | condition_occurrence | 1 or more SNOMED codes | All results whose source_value match any of the SNOMED codes |

## Appendix B - Algorithm Showcase

Here I take some algorithms from [OMOP's Health Outcomes of Interest](http://omop.org/HOI) and turn them into ConceptQL statements to give more examples.  I truncated some of the sets of codes to help ensure the diagrams didn't get too large.

### Acute Kidney Injury - Narrow Definition and diagnositc procedure

- ICD-9 of 584
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
    - '584'
    :right:
    - after
    - :left:
      - icd9
      - '584'
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

![](spec/44ec6743d5d77d15b8a487c2058bf3e455d34adc91c46ea05767f6e0e471a75e.png)

```No Results found.```

### Mortality after Myocardial Infarction #3

- Person Died
- And Occurrence of 410\* prior to death
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
    - 410*
    :right:
    - death
    - true
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

![](spec/307a8b5a7edd6e42f8be16523a4c939faf1a0533385c861d7004b6af8addd7d1.png)

```No Results found.```

### GI Ulcer Hospitalization 2 (5000001002)

- Occurrence of GI Ulcer diagnostic code
- Hospitalization at time of diagnostic code
- At least one diagnostic procedure during same hospitalization


```YAML
---
- union
- - place_of_service_code
  - '21'
- - visit_occurrence
  - - icd9
    - '410'
- - visit_occurrence
  - - union
    - - cpt
      - 0008T
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

```

![](spec/99392f56dfb0e5be3f45a12a7f1ba846d094e430f526dfeaa30b606837cd34c0.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 1 | 1 | visit_occurrence | 2010-03-12 | 2010-03-13 | Inpatient |
| 2 | 8 | visit_occurrence | 2009-09-17 | 2009-09-20 | Inpatient |
| 2 | 9 | visit_occurrence | 2009-04-12 | 2009-04-18 | Inpatient |
| 2 | 10 | visit_occurrence | 2010-06-26 | 2010-07-01 | Inpatient |
| 2 | 11 | visit_occurrence | 2009-08-31 | 2009-09-02 | Inpatient |
| 14 | 507 | visit_occurrence | 2008-09-12 | 2008-09-12 | Inpatient |
| 17 | 729 | visit_occurrence | 2010-05-22 | 2010-06-12 | Inpatient |
| 17 | 730 | visit_occurrence | 2008-09-19 | 2008-09-22 | Inpatient |
| 17 | 731 | visit_occurrence | 2010-06-02 | 2010-06-06 | Inpatient |
| 17 | 732 | visit_occurrence | 2010-06-16 | 2010-06-19 | Inpatient |

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

Some statements maybe very useful and it would be handy to reuse the bulk of the statement, but perhaps vary just a few things about it.  ConceptQL supports the idea of using variables to represent sub-expressions.  The variable operator is used as a place holder to say "some criteria set belongs here".  That variable can be defined in another part of the criteria set and will be used in all places the variable operator appears.

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


```YAML
---
- icd9
- '412'

```

![](spec/f6b4fc31703cfb6327bbbd4614af8bb72da6d39fa3d53ada63a70157f2fad80e.png)

| person_id | criterion_id | criterion_type | start_date | end_date | source_value |
| --------- | ------------ | -------------- | ---------- | -------- | ------------ |
| 17 | 1712 | condition_occurrence | 2008-08-25 | 2008-08-25 | 412 |
| 17 | 1829 | condition_occurrence | 2009-04-30 | 2009-04-30 | 412 |
| 37 | 4359 | condition_occurrence | 2010-02-12 | 2010-02-12 | 412 |
| 53 | 5751 | condition_occurrence | 2008-06-05 | 2008-06-05 | 412 |
| 59 | 6083 | condition_occurrence | 2009-07-19 | 2009-07-22 | 412 |
| 64 | 6902 | condition_occurrence | 2009-07-25 | 2009-07-25 | 412 |
| 71 | 7865 | condition_occurrence | 2008-11-16 | 2008-11-16 | 412 |
| 75 | 8397 | condition_occurrence | 2010-10-06 | 2010-10-06 | 412 |
| 79 | 8618 | condition_occurrence | 2009-01-28 | 2009-01-30 | 412 |
| 86 | 9882 | condition_occurrence | 2009-01-03 | 2009-01-09 | 412 |

### Filter Operator

Inspired by person_filter, why not just have a "filter" operator that filters L by R.  Takes L, R, and an "as" option.  As option temporarily casts the L and R streams to the type specified by :as and then does person by person comparison, only keeping rows that occur on both sides.  Handy for keeping procedures that coincide with conditions without fully casting the streams:


```YAML
---
- filter
- :left:
  - cpt
  - '99214'
  :right:
  - icd9
  - '799.22'
  :as: visit_occurrence

```

![](spec/c5329a7f4937096a57b2e01efb9d542f84a4e2329a1e9381d08c630583ccad37.png)

```No Results found.```

person_filter then becomes a special case of general filter:


```YAML
---
- filter
- :left:
  - cpt
  - '99214'
  :right:
  - icd9
  - '799.22'
  :as: person

```

![](spec/9139440329dcb815df89bc70182c3827868402a74ff64d0253706dcaff723dca.png)

```No Results found.```

Filter operator is the opposite of Except.  It only includes L if R matches.

### AS option for Except

Just like Filter has an :as option, add one to Except operator.  This would simplify some of the algorithms I've developed.

### How to Handle fact_relationship Table from CDMv5

Each relationship type could be a binary operator box read as L <relationship\> R. E.g. L 'downstream of' R would take a L stream and only pass on downstreams of rows in R stream.

We could implement a single operator that takes a relationship as an argument (on top of the L and R arguments) or we could create a operator class for each relationship.  I think it would be better to have a single relationship operator class and take the relationship as the argument.

The next question is: how do we actually join the two streams?  I suppose we could translate each "type" into a "domain" and then join where l.domain = domain_concept_id_1 and l.entity_id = fact_id_1 and R.domain = domain_concept_id_2 and R.entity_id = fact_id_2 where the relationship chosen = relationship_concept_id.

Yup, that should work.  Phew!

[^AIA]: J. Allen. Maintaining knowledge about temporal intervals. Communications of the ACM (1983) vol. 26 (11) pp. 832-843
