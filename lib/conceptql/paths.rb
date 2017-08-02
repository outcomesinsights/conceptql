module ConceptQL
  class << self
    def root
      (Pathname.new(__dir__) + ".." + "..").expand_path
    end

    def schemas_dir
      root + 'schemas'
    end

    def config_dir
      root + 'config'
    end

    def vocabularies_file_path
      ConceptQL.config_dir + "vocabularies.csv"
    end

    def multiple_vocabularies_file_path
      ConceptQL.config_dir + "multiple_vocabularies.csv"
    end

    def custom_vocabularies_file_path
      ConceptQL.config_dir + "vocabularies.custom.csv"
    end

    def custom_multiple_vocabularies_file_path
      ConceptQL.config_dir + "multiple_vocabularies.custom.csv"
    end
  end
end
