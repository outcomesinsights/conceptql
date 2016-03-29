# A Bit About Metadata

`ConceptQL.metadata` produces a hash containing all relevant metadata about ConceptQL, specifically which categories and operators are available in ConceptQL.

The hash contains two keys: "categories" and "operators".

## Metadata about Categories

The value of the "categories" hash is an array of hashes representing each available category in ConceptQL.  Each hash has two key/value pairs:

- name
    - The category's name
- priority
    - The position the category should have if you were to list the categories in order

## Metadata about Operators

Each operator in ConceptQL is listed in the metadata.json file under the "operators" key.

The operator metadata is a hash where the key is the name of an operator and the hash is the metadata specific to that operator.

The metadata for each operator should be complete enough that a UI can understand all of the parameters and constraints specific to that operator and render it accordingly.  Essentially, the metadata should be complete enough that entirely new operators can appear in the metadata and the UI should be able to render that operator and its parameters without needing to change anything in the code for the UI.

### Operator Metadata Outline

- min_upstreams
    - 0 or 1
    - 0 means this operator does not need inputs from an upstream operator
    - 1 means this operator needs input from at least one upstream operator
- max_upstreams
    - 0, 1, or 99
    - 0 means this operator does not take input from an upstream operator
    - 1 means this operator takes input from up to one upstream operator
    - 99 means this operator takes input from unlimited upstream operators
- preferred_name
    - If this option is present, this is the name of the operator to display in the UI
    - If this option is missing, run the name of the operator through the equivalent of ActiveSupport#humanize
- operation
    - The name of the operation
    - This is the name to use when translating the structure in the UI into a ConceptQL statement
- options
    - A hash of the parameters that an operation expects
    - Key is the name of the parameters (run through ActiveSupport#humanize to get the name to display in the UI)
    - Value is a hash described in Option Metadata Outline below
- categories
    - An array of arrays representing the categories this operator is assigned to
    - Each sub-array represents a path of categories and sub-categories that the operator is assigned to
    - At the moment, all sub-arrays are single element arrays and no sub-categories are used
    - So, it's safe to flatten the array of arrays and assign an operator to each of the categories in the flattened array
    - **If an operator has no categories assigned, it should NOT appear in the UI**
- arguments
    - Similar to options
    - When the UI generates the corresponding ConceptQL, values assigned to arguments should be listed as elements 1 thru XX in the array that represents the current operator
- desc
    - Description of the operator, to be displayed when the user is interacting with that operator
- predominant_domains
    - A list of one or more domains that the operator is known to represent
    - This should be used as a means to declare what domain color(s) to use to represent the operator and how many lines the operator should generate
    - This option should only appear in selection operators and casting operators
- basic_type
    - I don't know what this does but it seemed like information needed for Envy's JAM

### Option Metadata Outline

- type
    - Dictates what type of input the operator expects for this parameter
    - Can be one of the following types:
        - string
            - A string of text
        - integer
            - A whole number, positive or negative
        - boolean
            - Either true or false
            - Can be respresented by a checkbox or similar, toggleable UI item
        - codelist
            - Eventually the UI should provide a sophisticated means of selecting codes from a specific terminology (specified by the vocab option)
            - For now, expect a comma delimited list of codes in a textarea
        - upstream
            - Indicates that we need input from an upstream operator
- vocab
    - Specifies which terminology to use when presenting a list of codes to select from
    - Should only be used when type is codelist
- options
    - An array representing an enumeration of all possible values that can be used for this option/argument
    - The UI should present only these options for a user to choose and disallow any other input from the user
- default
    - The default value for this parameter
- required
    - True if this parameter must have a value
