---
id: conceptql-vox.1
title: 'A ConceptQL glossary: one precise definition per term, shared with other organizations'
status: captured
type: exploration
parent: conceptql-vox
created_at: 2026-11-12T18:31:14.399662+00:00
updated_at: 2026-11-12T20:42:30.658734+00:00
tags:
  - glossary
  - ontology
  - skos
  - spec
relationships:
  - target_id: conceptql-hzz
    rel_type: questioned-by
    created_at: 2026-11-12T20:33:35.209901+00:00
  - target_id: conceptql-m9s
    rel_type: questioned-by
    created_at: 2026-11-12T20:33:35.753847+00:00
  - target_id: conceptql-spe
    rel_type: questioned-by
    created_at: 2026-11-12T20:33:36.275601+00:00
---

EXPLORATION (2026-11-12). NOT RULED. Workshop in progress: Ryan speaks at length, and the session consolidates the ideas into defined terms.

## Goal

A glossary of the words that Ryan and Mark use for ConceptQL, each with one precise definition, used consistently in the spec and in talk about ConceptQL. ConceptQL is open source, and other research firms and pharma companies use different words for the same things.

## Origin

It came out of `conceptql-vox` (OWL ontology for AI-built cohorts). Ryan's points, condensed (the raw monologue of 2026-11-12 is kept in a private transcript archive, not in this public repo):

- ConceptQL is open source and should be usable by others.
- Ryan and Mark (and two earlier team members) spend much effort to choose words, give each a precise definition, and use it consistently: statement, algorithm, selection operator, upstream, downstream.
- Organizations use different words for the same thing: algorithm, phenotype, macro.
- Many related ideas are poorly or incompletely defined across the field: temporal logic, weights, counting, inpatient setting, outpatient setting.
- Ryan asked whether an ontology is the right way to communicate this glossary.

## Claude's position (2026-11-12)

Claude's earlier answer judged OWL reasoning, which is too narrow. A shared glossary across organizations is the job of SKOS (Simple Knowledge Organization System, a W3C standard for thesauri and glossaries). Each SKOS concept has one preferred label, alternative labels (for example "phenotype", "cohort definition", "macro" for "algorithm"), a definition, broader and narrower links, and match links to other organizations' terms (for example "inpatient setting" to OMOP's visit concepts). The definitions are the content. SKOS is only the publishing form. The spec build could check that the prose uses only preferred labels.

## Spec facts (checked 2026-11-12 in `docs/spec/README.cql.md`)

- The spec has no glossary section.
- Line counts (case-insensitive): "statement" 27, "window" 14, "algorithm" 11, "event" 7, "upstream" 6, "cohort" 2, "protocol" 0, "phenotype" 0.
- The Motivation section describes ConceptQL with cohorts: "criteria used to build cohorts from a claims database" and "Hand-coding the queries that extract cohorts from a dataset is slow". This conflicts with Ryan's distinction below, that an algorithm finds events and does not define a cohort.

## Term 1: algorithm versus cohort versus protocol (Ryan's rationale, condensed and neutral)

- A statement is ConceptQL's declarative form of a set of search criteria. It has the form of a Lisp S-expression: the first item is an operator, followed by arguments and keyword options. It is stored as JSON, because almost every language reads and writes JSON and people can read it.
- A statement represents an algorithm: search criteria applied to a data set to find events of interest.
- Every result is a relation (a set of rows) from an RDBMS. Each row has a person, dates, a pointer to the source row and its table, and a domain (a term taken from OMOP). A result about people still has dates.
- An algorithm has one job: detect one kind of event. It describes how to find the event, not when. This is why ConceptQL says "algorithm" and not "phenotype" or "cohort definition".
- Windows of time ("when the camera is on", Mark's phrase) are defined outside the algorithm. So one algorithm serves baseline, outcome and other windows unchanged, and the person who writes an algorithm does not reason about study windows.
- ConceptQL can compare events in time (nth occurrence, events within a window of other events), but that is not its main purpose.
- In Jigsaw, a protocol (study) builder composes algorithms and windows of time. The person who writes a protocol reasons about events in windows and trusts each algorithm, for example "diabetes, with one-in-two, in the baseline period".
- Because every algorithm returns its events as rows, the events that build a cohort are also available for analysis. Nobody queries the database a second time for them. Jigsaw's output is an analyst-ready data set.
- Contrast with OHDSI, stated with OHDSI's own definition: the Book of OHDSI defines a cohort as "a set of persons who satisfy one or more inclusion criteria for a duration of time", and a cohort definition specifies those criteria. A cohort definition returns persons and periods. A ConceptQL algorithm returns events, and the protocol supplies the periods. Ryan's account: the cohort tools that the team saw when ConceptQL was designed returned patients and windows, and analysts then queried again for the events. Ryan and Mark have not seen the event-first approach elsewhere.

## Claude's first consolidation (drafts for Ryan to correct, not ruled)

- **Statement**: a ConceptQL expression, stored as JSON. It has the form of an S-expression: an array whose first item names an operator, followed by arguments and an optional hash of options.
- **Algorithm**: a set of search criteria, written as a statement, that detects one kind of event in a data set. It says how to find the event, not when. Others say: phenotype, cohort definition (OHDSI), macro. These are close terms, not synonyms: a cohort definition defines patients, an algorithm defines events.
- **Event**: one result row of an algorithm. It has a person, a start date and an end date, a pointer to the source row and its table, and a domain (a term taken from OMOP).
- **Window of time**: a period in which a patient can be observed in the data ("when the camera is on", Mark's phrase). It is defined outside algorithms, so one algorithm can serve baseline, outcome and other windows unchanged.
- **Cohort**: the patients who meet a study's criteria, with their windows of time.
- **Protocol**: a Jigsaw composition of algorithms and windows of time. It yields a cohort and every event in each patient's windows, which is an analyst-ready data set.

Claude's observation: the text above holds two kinds of content. One kind is definitions, which are short and go in a glossary. The other is the design rationale (why events and not patients, why windows sit outside algorithms). The rationale is an argument, and it fits the spec's Motivation section better, with each glossary entry linking to it.

## Open

- Are the six draft definitions correct? Which words are missing (upstream, downstream, stream, selection operator, domain, inpatient setting, outpatient setting, weights, counting)?
- Where does the glossary live: a section of the spec, a source file (TSV or YAML) from which the spec section and a SKOS file are generated, or both?
- Does the spec define protocol and cohort, which are Jigsaw terms, or only contrast them with algorithm?
- Should the Motivation section stop saying that ConceptQL builds cohorts?

## UPDATE 2026-11-12: transcripts, tone, and operator terms

Ryan asked that the rationale be captured, and that the source monologues be kept so that definitions and rationale can be extracted from them later. Anything derived must contain no finger pointing, judgment, condescension or disparagement. He was unsure about naming OHDSI's "cohort definition": he does not want to offend, and he does not want to be so general that readers cannot tell what he means.

Ryan's definition of a selection operator, condensed: it reaches into the data set and pulls out the rows that match the algorithm's search criteria (for example ICD-9 or ICD-10 codes for diabetes). It is the part that runs SQL against the tables of the data set. Its rows become ConceptQL results with the standard columns, which downstream operators filter and refine. His account of the other operator kinds is in `conceptql-vox.2`.

### Facts checked (2026-11-12)

- `outcomesinsights/conceptql` is PUBLIC. Seeds in `.seeds/` are committed files, so everything in this seed becomes public at the next push.
- The private archive already holds the meeting transcripts and their curated extractions.

### RULED 2026-11-12 (Ryan)

- Raw monologues go to the private transcript archive, in a `transcripts/monologues/` directory. The 2026-11-12 monologue is stored there.
- No edited transcript goes into conceptql. The glossary and the rationale are derived from the monologues directly, in neutral language.
- OHDSI is named, and its approach is described with OHDSI's own published definition. The difference is stated as a difference in design goals.

### Draft definition

- **Selection operator**: an operator that queries the tables of the data set. It returns the initial events that match its search criteria, as ConceptQL results with the standard columns. Every other operator works downstream on results that a selection operator produced.

## UPDATE 2026-11-12: group 2 (results) and group 1 (the language)

Source: monologue 06 of 2026-11-12, in the private transcript archive. Condensed below.

### RULED 2026-11-12 (Ryan): row, result, record

- **Row** means a row of data in a data set, and only that.
- **Result** is the preferred term for a ConceptQL row. **Record** is a synonym, and the preferred term is "result". The spec now says "record" on 65 lines and "result" on 4, so the spec needs a wording pass.

### Draft definitions (Claude, from Ryan's account; not yet confirmed)

- **Row**: one row of a table in the data set.
- **Result**: one ConceptQL row. A selection operator builds results from the rows that it detects, restructured into the standard columns. A result keeps a reference to the row it came from, plus information for further filtering, mainly temporal filtering. Synonym: record (not preferred).
- **Stream**: the set of results that passes from one operator to the next. Ryan's caution: since about 2010, many "stream processing" query systems exist, and ConceptQL does not work like them. The glossary entry should say so.
- **Standard columns**: the columns that every result carries, defined in `Scope::DEFAULT_COLUMNS` (`lib/conceptql/scope.rb`): person_id, criterion_id, criterion_table, criterion_domain, start_date, end_date, source_value, source_vocabulary_id, label, column_family. In Ryan's view the core ones are person_id, criterion_table and criterion_id (together, the reference to the source row) and start_date and end_date. The others support recording and filtering. Operators can add more columns from `ADDITIONAL_COLUMNS` (value_as_number, provider_id and others).
- **Domain**: the kind of clinical fact (condition, procedure, observation). The term comes from OMOP, which stores each domain in its own table. ConceptQL was first built against OMOP CDM (version 4, as Ryan recalls), where the domain equaled the criterion table. Against the GDM, which stores data in fewer, more general tables, that is no longer true, and the domain matters much less. Results from different domains can be combined.
- **Event**: what a result represents. The `person` operator also yields events: with no upstream, each person's event has the birth date as start_date and end_date (confirmed in `person.rb`). This makes age arithmetic easy: birth date plus 65 years is the 65th birthday.
- **Operator**: in the code, a Ruby class that performs one operation. In general terms, a function applied to the data set or to results. Only a selection operator reads the data set. Every other operator works on upstream results.
- **Argument**: an unnamed, positional piece of information given to an operator. An operator can take a variable number of arguments.
- **Option**: a named piece of information given to an operator, stored in the hash of the statement (a keyword argument).
- **Label**: an option that every operator accepts. It names the results that the operator produces in this algorithm, for example "diabetes" on a selection operator with diabetes codes. Code check: the label is also written into each result's `label` column, and a `recall` operator selects results by it, so each label in a statement must be unique (`operator.rb`, the `label` option). Ryan's account did not mention this second role. Decide whether the definition includes it.
- **Downstream**: everything in a statement that comes after a given operator. Each operator produces results, and later stages are downstream of them.
- **Upstream**: the results that come into an operator.

## UPDATE 2026-11-12: periods and windows (group 3)

Source: monologue 07 of 2026-11-12, in the private transcript archive. Condensed below.

### Ryan's rule (stated 2026-11-12)

A **period** is a span of time in the data set. A **window** is a span of time in a study. Windows belong mostly to the protocol, which is in Jigsaw.

### Draft definitions (Claude, from Ryan's account; not yet confirmed)

- **Information period**: a span of time in which the data set has a given kind of information about a person, for example enrollment in Medicare Part B, or in Part D. Part D enrollment is what gives insight into a person's medications. A person can have several information periods of different types, and they can overlap. Each one is a time "when the camera is on" for its kind of information. Code check: the `information_periods` operator selects them, filtered by types from the GDM_INFORMATION_TYPE vocabulary (for example PARTD).
- **Observation period (OMOP)**: the OMOP CDM 5.4 definition, verbatim: "This table contains records which define spans of time during which two conditions are expected to hold: (i) Clinical Events that happened to the Person are recorded in the Event tables, and (ii) absence of records indicate such Events did not occur during this span of time." A person's observation periods "will not overlap or be back to back". For claims data, the CDM says the observation period "can be considered as the time period the Person is enrolled with a payer".
- **Window (ConceptQL sense)**: a date range of one person that a calling program applies to a statement, to limit where the algorithm can find events. Mechanism: the window table (spec section "Window Tables"). An algorithm does not contain windows and must not assume that it has one. This is what lets one algorithm serve any study window.
- **time_window operator**: a different thing with a similar name. It moves the dates of results inside a statement. Windows that a calling program applies still limit its output.
- **Protocol terms** (Jigsaw, not ConceptQL): study window; index date (T0), which divides the study window into baseline and follow-up; inclusion and exclusion criteria and baseline exposures (Ryan's preferred term, instead of "baseline variables") in baseline; outcomes and censoring in follow-up. A protocol can adjust the study window. Ryan expects that Mark's ontology and glossary will cover these terms.

### Claude's check of Ryan's inference about OMOP (2026-11-12)

Ryan's account: an OMOP observation period reads like an analysis period, not a span in which information exists. He asked to be checked on this.

- The CDM's own definition is about data capture: when events are recorded. It is not defined as a study period. On this point, the inference does not match the text.
- Two differences from ConceptQL's information periods are real, and both can be stated neutrally from the CDM text. (1) OMOP's periods of one person do not overlap and do not say which kinds of data they cover. ConceptQL's information periods have a type, so Part B and Part D coverage stay separate. (2) OMOP's definition includes an assumption: inside the period, absence of a record means the event did not occur. The ETL fixes that assumption into the data. The GDM leaves such decisions to the analysis. This second point is the neutral form of Ryan's view on ETL-time decisions.

### Questions raised (not ruled)

- The spec says that, inside windows, each selection operator keeps only results whose start_date is in the window. So a result that starts inside a window and ends after it is kept, with its end_date unchanged. Ryan described data outside a window as "ignored as though it doesn't exist at all". Which one is the definition?
- "Window" and the `time_window` operator are easy to confuse. Does the glossary only separate them, or does one of them get a new name?
- The protocol terms belong to Jigsaw and to Mark's work. Does the ConceptQL glossary list them with a link to Mark's glossary, or leave them out?

## UPDATE 2026-11-12: answers on windows, and items for review with Mark (2026-11-13)

Source: monologue 08 of 2026-11-12, in the private transcript archive.

### Ryan's answers

- **Window (general sense)**: "in our parlance, a window is just a span of time", with nothing more specific. This fits the earlier rule: a period is a span in the data set, and a window is a span in a study.
- **time_window**: Ryan described it as an option that the calling program passes into ConceptQL, which sets the range or ranges in which events can be looked for.
- **Protocol terms**: record them now (done in the update above), but do NOT put them in the ConceptQL glossary yet. Harmonize them with Mark first.

### Code check of the time_window answer (Claude, 2026-11-12)

The code has two separate things, and Ryan's description matches the second one:

1. `time_window` is an operator inside a statement (`lib/conceptql/operators/time_window.rb`). It moves the start_date and the end_date of each upstream result, by its `start` and `end` options.
2. The calling program passes window options to ConceptQL, outside the statement (`lib/conceptql/window.rb`). There are three kinds: a date range for every person (`start_date` and `end_date`), a window table with one or more date ranges for each person (`window_table`, with `adjust_window_start` and `adjust_window_end`), and a person filter (`person_ids`). t_shank passes `window: { window_table: ..., scope_by: ... }`.

So the glossary needs two entries with two names. The name "time window" now belongs to the operator. A term for the second thing is still needed, for example "window" or "scope window" (the code comment says "scope windows").

### Code fact for question 3 (what a window keeps)

The behavior is a setting, not a single rule. `Window.prep_options` reads the option `scope_by`, which has three values:

- `start_date` (the default): a result is kept if its start_date is in the window.
- `end_date`: a result is kept if its end_date is in the window.
- `date_range`: a result is kept only if both its start_date and its end_date are in the window. The DateRange window checks `window start <= result start` and `result end <= window end`.

t_shank stores the value for each study criterion (`study_criterion.scope_by || :start_date`, in `t_shank/lib/t_shank/algo.rb`). Tests cover two values (`test/statements/icd9/results_with_scope_windows_both_dates.json`, `..._end_date_only.json`). The spec mentions `scope_by` on 0 lines. Its Window Tables section describes only the default.

No mode cuts a result at the window edge.

### FOR REVIEW WITH MARK (2026-11-13)

1. What does a window keep? Confirm the three `scope_by` modes, and say whether start_date stays the default. Ryan did not know what the original assumption was. The spec should then document `scope_by`.
2. The protocol terms: study window, index date (T0), baseline, follow-up, inclusion and exclusion criteria, baseline exposures, outcomes, censoring. Harmonize them with Mark's ontology and glossary before any of them enters the ConceptQL glossary.
3. A name for the windows that a calling program applies, kept separate from the `time_window` operator.

## UPDATE 2026-11-12: time_window, care settings (group 5)

Source: monologue 09 of 2026-11-12, in the private transcript archive. Condensed below.

### time_window

Ryan confirmed that `time_window` is an operator that moves the start_date and end_date of its upstream results. He added that with no upstream it produces windows of time for each person in the data set, for use as a right-hand stream.

Code check (Claude): the current `time_window` requires exactly one upstream (`allows_one_upstream`, `validate_one_upstream` in `time_window.rb`). Windows for each person come from an upstream that has one result per person, such as `person` (birth date) or `information_periods`. Example: `["time_window", ["person"], {"start": "65y", "end": "65y"}]` gives each person's 65th birthday. Open: did an older version accept no upstream, or is this the pattern Ryan meant?

### Inpatient and outpatient setting (Ryan's account)

- The terms are poorly defined across the field. Ryan is not the expert on them.
- An inpatient setting is meant to cover an admission to a hospital for a stay. In practice the line is unclear:
  - Some data sets define it by the source file, for example the MedPAR file in Medicare.
  - Do carrier claims for services in a hospital belong to the inpatient setting?
  - When an emergency room visit becomes an admission, where is the line between its outpatient part and its inpatient part?
  - Is the place of service code the deciding fact?
  - Are skilled nursing facilities separate from inpatient? Sometimes yes, sometimes no.
- Outpatient visits have the same ambiguity, and the source file is again often the deciding fact.
- ConceptQL's approach: the data set declares, through a mapping, which rows are inpatient and which are outpatient. The ETL stores the concrete facts (the source file, the place of service and others). The choice of setting is close to an analysis decision, so it lives in a mapping. Changing the mapping changes which events count as inpatient, with no new ETL.

Code check (Claude): `one_in_two_out` calls `build_where_from_codes(db, ["inpatient"])` (`behaviors/provenanceable.rb`). The keyword "inpatient" names a concept in the Jigsaw provenance vocabularies: JIGSAW_FILE_PROVENANCE_TYPE and JIGSAW_CODE_PROVENANCE_TYPE (`data_model/gdm.rb`). A result counts as inpatient when its `file_provenance_type` or its `code_provenance_type` is a DESCENDANT of that concept. So the mapping is the concept hierarchy of those vocabularies, not an OHDSI visit concept, and descendants count, not ancestors. A result can only be confirmed if it has inpatient, outpatient or carrier_claim provenance (`one_in_two_out` desc).

### Draft definitions (not yet confirmed)

- **Provenance**: the facts about where a row came from: its source file (file provenance) and the role of its code in the claim (code provenance, for example primary diagnosis). The GDM stores both as concepts.
- **Inpatient setting / outpatient setting**: in ConceptQL, a property that the data set's provenance mapping declares, not a fixed rule. A result is inpatient when its file or code provenance concept descends from the "inpatient" concept of the Jigsaw provenance vocabularies. The glossary entry should list the common ambiguities above, so that a reader knows that the definition depends on the data set.

### RULED 2026-11-12 (Ryan)

"Weights" and "counting" are not poorly defined, and they have no place in the glossary.
