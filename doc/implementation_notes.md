# ConceptQL Implementation Notes
And here is where I record information about some of the decisions I made.

## Define/Recall
- Sequel's create table statement runs out-of-band with rest of ConceptQL statemnt
    - Gets executed immediately
    - This is going to be very slow for large datasets :-(
- I had to retool Tree and Query and Graph to expect an array of concepts in a ConceptQL statement
    - I'm not sure I like this
    - A ConceptQL statement perhaps should be only a single statement at the end
- Defines need to occur before they are used
    - Most languages have a "forward definition" ability
        - I have no use cases for when we might need those?
        - Perhaps a definition that uses a definition that doesn't exist?
        - Is that recursive?
    - Is that something we want/need in ConceptQL?


## Values
- I had considered comparing a result set with a between operator, but this implies that the R stream needs a range somehow
    - I don't think supporting a range is a good idea right now


