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


## Bad Ideas
Here is where I intend to record bad ideas that appear to be blind allies

### Removing person-only rows from a stream after ANDing
- Theoretically, any result set that passes up through an AND node carries all the valid person IDs with it, so it is redundant to carry results that are just person-only.  It would make sense to eliminate them.
- NO BAD IDEA
    - We have to check to see if the stream is exclusively person-only.  In that case, it is unsafe to eliniate those results because we'd end up removing all results from the stream
        - We could implement this check, but let's do that later when we want to optimize things
             - Also, what happens if we cast to visit later and we've removed all person-only results?  This could cause odd behavior

### Treating Patient Streams as "Eternal" when they encounter a temporal node
I had created a rather sophisticated system of how to handle a patient stream entering a temporal node.

The basic premise is that patient information (gender, race, etc) is "timeless" or "eternal" and so if a patient stream is the R stream in a temporal node and the L stream is, say, a stream of MIs, what is the result?  I proposed that the MI would be filtered down to only those patients that appear in the R stream.

Likewise, if the MI stream is the R stream and the person stream is the L stream, what's the result?  Same thing.  Only patients common to both streams are passed through the L stream.  But patients DO have a date associated with them: their date of birth.  And, by passing a patient stream through a time_shift node of say, +50yr, we can use that patient stream in the R stream of a temporal node to filter the L stream by the patient being 50 years old.
