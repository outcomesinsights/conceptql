# frozen_string_literal: true

# Pathname is core only from Ruby 4.0; on 3.x a clean `gem install` (no Bundler
# preloading it) fails in ConceptQL.root without this. RuboCop targets 4.0.
require "pathname"

module ConceptQL
  class << self
    def root
      Pathname.new(__dir__).parent.parent.expand_path
    end

    def schemas_dir
      root / "schemas"
    end

    def config_dir
      root / "config"
    end

    def vocabularies_file_path
      ConceptQL.config_dir / "vocabularies.csv"
    end

    # A pinned copy of vocabulary_formats.tsv (ConceptQL::Vocabularies::Formats)
    def vocabulary_formats_file_path
      ConceptQL.config_dir / "vocabulary_formats.tsv"
    end

    # The vocabulary_formats commit that the copy came from
    def vocabulary_formats_sha_file_path
      ConceptQL.config_dir / "vocabulary_formats.sha"
    end

    def multiple_vocabularies_file_path
      ConceptQL.config_dir / "multiple_vocabularies.csv"
    end

    def custom_vocabularies_file_path
      Pathname.new(ENV["CONCEPTQL_CUSTOM_VOCABULARIES"] || ConceptQL.config_dir / "vocabularies.custom.csv")
    end

    def custom_multiple_vocabularies_file_path
      Pathname.new(ENV["CONCEPTQL_CUSTOM_MULTIPLE_VOCABULARIES"] || ConceptQL.config_dir / "multiple_vocabularies.custom.csv")
    end

    def race_file
      ConceptQL.config_dir / "race.yml"
    end

    # The ConceptQL specification, shipped in the gem for applications that
    # serve it to readers (the Jigsaw diagram editor serves it over MCP).
    def spec_path
      root / "docs" / "spec" / "README.md"
    end
  end
end
