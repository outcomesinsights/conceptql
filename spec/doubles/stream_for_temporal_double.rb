class StreamForTemporalDouble < ConceptQL::Operators::Operator
  def query(db)
    db.from(:table)
  end
end

