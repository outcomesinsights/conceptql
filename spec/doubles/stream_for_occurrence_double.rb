class StreamForOccurrenceDouble < ConceptQL::Operators::Node
  def query(db)
    ds = db.from(:table)
    # Occurrence needs window functions to work
    meta_def(ds, :supports_window_functions?){true}
    ds
  end

  def evaluate(db)
    query(db)
  end

  # Stole this from:
  # https://github.com/jeremyevans/sequel/blob/63397b787335d06de97dc89ddf49b7a3a93ffdc9/spec/core/expression_filters_spec.rb#L400
  #
  # By default, the Sequel.mock datasets don't allow window functions, but I need them
  # enabled for testing
  #
  # I saw that Sequel tests had this little nugget in them to temporarily enable
  # window functions and sure enough, it works
  def meta_def(obj, name, &block)
    (class << obj; self end).send(:define_method, name, &block)
  end
end

