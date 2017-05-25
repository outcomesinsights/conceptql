module ConceptQL
  def self.root
    (Pathname.new(__dir__) + ".." + "..").expand_path
  end

  def self.schemas
    root + 'schemas'
  end
end
