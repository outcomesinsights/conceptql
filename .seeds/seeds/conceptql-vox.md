---
id: conceptql-vox
title: Should ConceptQL pair with an OWL ontology for AI-driven cohort construction, or with test patients and an MCP tool?
status: captured
type: exploration
created_at: 2026-11-09T15:18:59.901716+00:00
updated_at: 2026-11-09T15:18:59.901716+00:00
tags:
  - ai
  - ontology
  - owl
  - shacl
  - verification
  - mcp
---

EXPLORATION (2026-11-09). NOT RULED. Nothing here is approved for build.

## Origin

Mark sent Ryan a ChatGPT-written proposal: "ConceptQL, Ontologies, and AI-Driven Cohort Construction". Its claim: combine ConceptQL with a formal OWL ontology of epidemiological concepts and an independent verification framework, so that an LLM builds cohorts from well-defined operators instead of writing SQL. The full text is below.

Ryan's questions, verbatim:

```
what is SHACL? what is your take on all this?  do you think llms are going to take advantage of owl?
```

## Terms

- OWL (Web Ontology Language): a W3C language that describes what concepts mean. A reasoner infers new facts from OWL axioms. OWL assumes an open world: a fact that nobody stated is unknown, not false.
- SHACL (Shapes Constraint Language, W3C 2017): checks that an RDF graph has a required form, as JSON Schema checks JSON. Example rule: "every cohort has exactly one index date, of type date". SHACL assumes a closed world.

## What was checked

- All eight operators that the proposal names exist in `lib/conceptql/operators/`: information_periods, contains, during, any_overlap, before, after, time_window, episode.
- `Operator` already declares structural validations (validate_one_upstream, validate_required_options, validate_unsupported_options, validate_codes_match and others in `operator.rb`). `Query#validation_errors` runs them.
- `ConceptQL.metadata` already gives a machine-readable catalog of the operators: arguments, options, descriptions.
- `ConceptQL::DiagramRenderer` already draws a statement as a diagram. The spec build already runs every example on the DuckDB fixture and records the results in `docs/spec/examples/*.json`.

## Assessment (Claude, 2026-11-09)

The main idea is correct: constrain the model to a specified language and verify its output independently. ConceptQL already does most of the first half.

The ontology layer is the weak part. The proposal's own example is a model that picks `any_overlap` where the study needs `contains`. An ontology cannot catch this. Both are valid temporal relations, and the error is in how the model read the researcher's sentence. Two checks would catch it:

1. Small synthetic patients at the boundaries, with answers calculated by hand. Example: a patient whose information period ends one day before the required lookback is complete. The test states whether that patient is in the cohort.
2. A plain-English description or a diagram of the generated statement, which the researcher confirms before the run.

The proposal reads as generic. It would apply almost unchanged to any query language.

## Will LLMs use OWL? (Claude's expectation: little direct use)

- LLMs see far more SQL, JSON and Python than OWL or Turtle in training, and write those more reliably.
- OWL's open-world assumption conflicts with cohort logic. "No diagnosis in the lookback" means none was recorded, which is a closed-world statement.
- LLM tooling has moved to typed tool calls, JSON Schema and MCP, not to the semantic web.
- OWL is useful where it already lives, in vocabularies. SNOMED CT is built in OWL. ConceptQL already uses concept hierarchies through the OHDSI `concept_ancestor` table.

This is a forecast, not a measurement.

## Directions (not ruled)

(a) An MCP server over ConceptQL with four tools: read operator metadata, validate a statement, run it on the DuckDB fixture, return the diagram. Cost is low because each piece exists.
(b) A suite of boundary-case test patients with hand-calculated cohort membership for the temporal operators. This is the verification that the proposal asks for, and it also tests ConceptQL itself.
(c) A plain-English rendering of a statement from operator metadata, for the researcher to confirm.
(d) The proposal's direction: an independent OWL ontology of epidemiological concepts plus a mapping layer to ConceptQL operators. Highest cost. Its benefit over (a) to (c) is not shown.

Open question for Ryan and Mark: is the goal model-written cohorts that a researcher confirms (a to c are enough), or interchange with other cohort tools (where an ontology could help)?

## Source text (Mark, via ChatGPT), verbatim

```
ConceptQL, Ontologies, and AI-Driven Cohort Construction

Executive Summary
ConceptQL already provides much of the infrastructure needed for reliable AI-driven cohort construction. It is a structured language with formally specified, composable cohort operations that can be translated into executable SQL.

The opportunity is to combine ConceptQL with a formal epidemiological ontology and an independent verification framework. This would allow AI to construct cohorts using well-defined concepts and operations, while providing mechanisms to determine whether the resulting algorithms accurately reflect researchers' intentions.

The goal is not to replace ConceptQL with an ontology. It is to make ConceptQL ontology-aware and use it as a controlled interface between AI-generated cohort definitions and executable analyses.

1. What ConceptQL Already Provides
ConceptQL consists of two primary GitHub repositories:
- ConceptQL implementation — The Ruby implementation that translates structured research algorithms into SQL.
- ConceptQL specification — Defines the language, operators, and their expected behavior.

ConceptQL includes operators relevant to epidemiological cohort construction, such as:
information_periods  Select person-specific information periods
contains             Identify intervals that completely contain other intervals
during               Evaluate temporal inclusion
any_overlap          Identify overlapping intervals
before / after       Evaluate temporal relationships
time_window          Construct or manipulate temporal windows
episode              Support episode-based analysis
These operations allow cohort algorithms to be expressed without requiring AI to invent SQL implementations of fundamental epidemiological operations.

2. How an Ontology Complements ConceptQL
OWL ontology                Defines epidemiological concepts and their relationships
ConceptQL specification     Defines the operational semantics of cohort-building functions
ConceptQL interpreter       Converts structured cohort definitions into executable SQL
AI                          Interprets research questions and assembles ConceptQL expressions
Verification framework      Determines whether AI-generated expressions accurately implement the intended cohort definition
For example, an ontology could define an information period as a temporal interval associated with a particular person within a particular data source.
ConceptQL's information_periods operator retrieves representations of these periods, while operators such as contains and any_overlap implement specific temporal relationships.
Importantly, the ontology establishes the meaning of these concepts independently of ConceptQL. ConceptQL supplies the computational behavior needed to use them in analyses.

3. Proposed Architecture for AI-Driven Cohort Construction
1. Researcher defines a cohort in natural language. For example, patients with diabetes who have 12 months of continuous information before their index date.
2. AI interprets the request using the ontology. The ontology establishes the meaning of information periods, index dates, lookback periods, and other epidemiological concepts.
3. AI generates a ConceptQL expression. The AI selects and composes existing, formally specified operators rather than writing unrestricted SQL.
4. The expression undergoes independent verification. A separate mechanism evaluates whether the chosen operators, parameters, and temporal relationships match the intended cohort definition.
5. ConceptQL translates the expression into SQL. Its existing interpreter executes the cohort algorithm against the underlying data.
6. The resulting cohort undergoes additional checks. These may include structural validation, boundary-condition tests, and comparisons against independently established expected results.
This architecture substantially narrows the AI's responsibility. Rather than implementing every epidemiological operation from scratch, AI selects and composes operations whose behavior has already been specified.

4. Why Independent Verification Is Essential
Using ConceptQL does not automatically guarantee that AI interprets a cohort definition correctly.
For example, an AI might use any_overlap when the study requires complete temporal containment. Both expressions could be syntactically valid and execute successfully, while producing different populations.
Therefore, verification should occur at two levels:
Before execution: Semantic verification. Check whether the generated ConceptQL expression accurately represents the intended cohort definition. This may involve ontology-based reasoning, operator type checking, structural constraints, and explicit temporal requirements.
After execution: Result verification. Evaluate whether the resulting cohort satisfies the study's eligibility criteria. Tests should address boundary conditions, information-period gaps, incomplete coverage, and potential false inclusions or exclusions.
SHACL may be useful for validating structured representations, but SHACL alone cannot establish that every eligible person was included or that the AI chose the correct cohort logic.
Independent reference cases, trusted operations, and executable specifications are needed for stronger assurance.

5. The Opportunity: Ontology-Aware ConceptQL
- Assigning formal semantic identifiers to ConceptQL operations and the epidemiological concepts they use.
- Defining input and output types for operators using ontology concepts.
- Mapping ConceptQL's temporal operations to formally defined temporal relationships.
- Specifying constraints governing valid operator compositions.
- Automatically detecting certain semantic mismatches between cohort criteria and generated expressions.
- Generating test cases and verification requirements from formal cohort specifications.
- Maintaining traceability from a researcher's original intent through the ConceptQL expression to the resulting cohort.
The ontology should remain independent of ConceptQL, with a separate semantic mapping layer connecting the two. This would allow the ontology to support other cohort-building tools and data platforms.

6. What Exists and What Remains to Be Developed
Structured cohort-expression language                          Exists in ConceptQL
Composable cohort operators                                    Exists in ConceptQL
SQL execution through an interpreter                           Exists in ConceptQL
Documented temporal operator semantics                         Exists in the ConceptQL specification
Alignment with a formal epidemiological ontology               Proposed; needs assessment
Ontology-grounded AI generation of ConceptQL                   Proposed capability
Independent semantic verification of AI-generated definitions  Proposed capability
Automated conformance testing against formal cohort specs      Proposed capability

7. Recommended Direction
- Develop or adopt a formal ontology of epidemiological concepts, including information periods, cohort entry, and temporal relationships.
- Establish semantic mappings between ontology concepts and ConceptQL operators.
- Use AI to translate research questions into ontology-grounded ConceptQL expressions.
- Develop an independent verification framework to determine whether those expressions faithfully implement the researcher's cohort definition.
- Use the existing ConceptQL interpreter for execution.

Central Takeaway
ConceptQL provides the operational foundation; the ontology provides the semantic foundation; and an independent verification framework provides evidence that AI-generated cohorts implement the intended epidemiological definitions.
The key architectural objective is to shift from trusting AI-generated code to verifying AI-generated cohort specifications against formally defined epidemiological concepts and trusted computational operations.
```
