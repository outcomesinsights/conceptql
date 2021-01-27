module ConceptQL
  module Provenanceable

    def self.included(base)
      base.require_column :file_provenance_type
      base.require_column :code_provenance_type
    end

    FILE_PROVENANCE_TYPES_VOCAB = "JIGSAW_FILE_PROVENANCE_TYPE"
    CODE_PROVENANCE_TYPES_VOCAB = "JIGSAW_CODE_PROVENANCE_TYPE"

    CODE_SEPARATOR = ":"

    # Creates hash of provenance type concept codes by vocabulary_id (JIGSAW_FILE_PROVENANCE_TYPE, JIGSAW_CODE_PROVENANCE_TYPE)
    #
    # == Returns:
    # Hash with provenance type concept_codes by vocabulary_id
    #
    def provenance_types(db)
      @provenance_types ||= ConceptQL.with_lexicon(db) do |lexicon|
        lexicon.with_db do |ldb|
          ldb[:concepts].where(vocabulary_id: [FILE_PROVENANCE_TYPES_VOCAB,CODE_PROVENANCE_TYPES_VOCAB]).select_hash_groups(:vocabulary_id, [:concept_code, :id])
        end
      end
    end

    def base_file_provenance_types
      @base_file_provenance_types ||= provenance_types[FILE_PROVENANCE_TYPES_VOCAB].to_h
    end

    def base_code_provenance_types
      @base_code_provenance_types ||= provenance_types[CODE_PROVENANCE_TYPES_VOCAB].to_h
    end

    # Creates array of all unique file provenance codes
    #
    # == Returns:
    # Array with every combination of file and code type separated by "_"
    #
    def allowed_file_provenance_types
      @allowed_file_provenance_types ||= std_code_concept_ids[FILE_PROVENANCE_TYPES_VOCAB].keys
    end

    # Creates array of all unique combinations of allowed file provenance and code provenance types
    #
    # == Returns:
    # Array with every combination of file and code type separated by "_"
    #
    def allowed_code_provenance_types
      @allowed_code_provenance_types ||= std_code_concept_ids[CODE_PROVENANCE_TYPES_VOCAB].keys
    end

    # Takes list of codes (inpatient, outpatient_primary, etc) or concept ids and returns a Sequel or statement to be used in where clause of data stream
    #
    # GDM:
    #   File type provenance codes are looked up in the file_provenance_type field and code type provenance are looked up in the code_type_proenance field
    #   If a code is used that is both (ex: outpatient_primary) then the outpatient concept ids will be anded with the primary concept ids.
    #
    # OMOP:
    #   All omop concept ids are single ids with mix of file and code type provenance and as such are only looked up in the code_provenance_type field
    #   If a code is used that is both (ex: outpatient_primary) then concept ids looked up in code_provenance_type will be the set of outpatient concept ids
    #   that are also found in the set of primary concept ids.
    #
    # == Parameters:
    # codes::
    #   Array of standard provenance codes to get related concept ids split by file and code type provenance
    #
    # == Returns:
    # A ruby Sequel or statement
    #
    def build_where_from_codes(db, codes)

      codes = codes

      build_std_code_concept_ids(db, codes)

      w = []

      w = concept_ids_by_code(codes).each_with_object([]){|code, arr|
        file_prov_concept_ids = code[1][FILE_PROVENANCE_TYPES_VOCAB].to_a.map(&:to_i)
        code_prov_concept_ids = code[1][CODE_PROVENANCE_TYPES_VOCAB].to_a.map(&:to_i)

        if !file_prov_concept_ids.empty? || !code_prov_concept_ids.empty?
          res = {}

          if gdm?
            res[:file_provenance_type] = file_prov_concept_ids unless file_prov_concept_ids.empty?
            res[:code_provenance_type] = code_prov_concept_ids unless code_prov_concept_ids.empty?
          else
            # For omop get concept ids that are both in file and code if both contain values
            res[:code_provenance_type] = (file_prov_concept_ids & code_prov_concept_ids) if !file_prov_concept_ids.empty? & !code_prov_concept_ids.empty?
            res[:code_provenance_type] = file_prov_concept_ids if !file_prov_concept_ids.empty? & code_prov_concept_ids.empty?
            res[:code_provenance_type] = code_prov_concept_ids if !code_prov_concept_ids.empty? & file_prov_concept_ids.empty?
          end
          arr << res
        end
      }

      return Sequel.|(*w) unless w.empty?
      return Sequel.lit("0=1")
    end

    # Takes list of codes (inpatient, outpatient_primary, etc) and returns hash of related concepts ids by code and provenance type
    #
    # == Parameters:
    # codes::
    #   Array of standard provenance codes to get related concept ids split by file and code type provenance
    #
    # == Returns:
    # A hash in the form:
    # {
    #  inpatient: {JIGSAW_FILE_PROVENANCE_TYPE: [related concept ids], JIGSAW_CODE_PROVENANCE_TYPE: nil },
    #  outpatient_primary: {JIGSAW_FILE_PROVENANCE_TYPE: [ 'outpatient' related concept ids], JIGSAW_CODE_PROVENANCE_TYPE: [ 'primary' related concept ids] }
    # }
    #
    def concept_ids_by_code(codes)
      codes.map{|code|
        code = code.to_s

        file_type = file_provenance_part_from_code(code)
        code_type = code_provenance_part_from_code(code)

        h = {}

        # Look up code in std_code_concept_ids and use if not nil otherwise use submitted value
        h[FILE_PROVENANCE_TYPES_VOCAB] = std_code_concept_ids[FILE_PROVENANCE_TYPES_VOCAB][file_type]

        if h[FILE_PROVENANCE_TYPES_VOCAB].nil?
          h[FILE_PROVENANCE_TYPES_VOCAB] = [file_type] unless file_type.nil?
        end

        # Look up code in std_code_concept_ids and use if not nil otherwise use submitted value
        h[CODE_PROVENANCE_TYPES_VOCAB] = std_code_concept_ids[CODE_PROVENANCE_TYPES_VOCAB][code_type]

        if h[CODE_PROVENANCE_TYPES_VOCAB].nil?
          h[CODE_PROVENANCE_TYPES_VOCAB] = [code_type]  unless code_type.nil?
        end

        h[FILE_PROVENANCE_TYPES_VOCAB] = h[FILE_PROVENANCE_TYPES_VOCAB].uniq unless h[FILE_PROVENANCE_TYPES_VOCAB].nil?
        h[CODE_PROVENANCE_TYPES_VOCAB] = h[CODE_PROVENANCE_TYPES_VOCAB].uniq unless h[CODE_PROVENANCE_TYPES_VOCAB].nil?

        [code, h]
      }.to_h
    end

    def build_std_code_concept_ids(db, codes)
      @std_code_concept_ids = get_related_concept_ids_by_codes(db, codes)
    end

    def std_code_concept_ids
      @std_code_concept_ids
    end

    # Takes list of codes (inpatient, outpatient_primary, etc) and returns hash of related concept ids
    # for the file prov part of code and code prov part of code
    #
    # == Parameters:
    # codes::
    #   Array of standard provenance codes to get related concept ids split by file and code type provenance
    #
    # == Returns:
    # A hash in the form:
    # {
    #  JIGSAW_FILE_PROVENANCE_TYPE: {
    #    inpatient: [related concept ids],
    #    outpatient: [related concept ids]
    #  }
    #  JIGSAW_CODE_PROVENANCE_TYPE: {
    #    primary: [related concept ids]
    #  }
    # }
    #
    def get_related_concept_ids_by_codes(db, codes)

      # Get all character based codes
      file_type_codes = codes.map{|code| file_provenance_part_from_code(code)}.select{|c| !c.nil? && c.to_i.zero?}.uniq
      code_type_codes = codes.map{|code| code_provenance_part_from_code(code)}.select{|c| !c.nil? && c.to_i.zero?}.uniq

      conditions = []
      conditions << {vocabulary_id: FILE_PROVENANCE_TYPES_VOCAB, concept_code: file_type_codes} unless file_type_codes.to_a.empty?
      conditions << {vocabulary_id: CODE_PROVENANCE_TYPES_VOCAB, concept_code: code_type_codes} unless code_type_codes.to_a.empty?

      res = {FILE_PROVENANCE_TYPES_VOCAB => {}, CODE_PROVENANCE_TYPES_VOCAB => {}}
      if !conditions.empty?
        ConceptQL.with_lexicon(db) do |lexicon|
          lexicon.with_db do |ldb|
            q = ldb[:concepts]

            q = q.where(Sequel.|(*conditions))

            q = q.from_self(alias: :c).join(ldb[:ancestors], {ancestor_id: :id}, table_alias: :ancestors)

            ConceptQL.logger.debug("x"*80)
            ConceptQL.logger.debug({
              thread: Thread.current,
              conditions: conditions,
              ancestors: ldb[:ancestors].count,
              concepts: ldb[:concepts].count,
            }.pretty_inspect)

            res = q.select_hash_groups([Sequel[:c][:vocabulary_id], Sequel[:c][:concept_code]], [Sequel[:ancestors][:ancestor_id], Sequel[:ancestors][:descendant_id]])

            ConceptQL.logger.debug(res.pretty_inspect)
            res = res.each_with_object({FILE_PROVENANCE_TYPES_VOCAB => {}, CODE_PROVENANCE_TYPES_VOCAB => {}}){|c,h|
              h[c[0][0]].merge!( [[c[0][1],c[1].flatten]].to_h){|key,new_v,old_v| (new_v.flatten + old_v.flatten).uniq}
            }
          end
        end
      end

      return res
    end

    # Takes a code (ex: outpatient_primary) and returns the file provenance type part
    #
    # == Parameters:
    # code::
    #   String
    #
    # == Returns:
    # file provenance type part of code
    # ex: file_provenance_part_from_code("outpatient:primary") returns "outpatient"
    #
    def file_provenance_part_from_code(code)
      code_split = code.split(CODE_SEPARATOR)

      return code_split[0] unless code_split[0].empty?
      return nil
    end

    # Takes a code (ex: outpatient:primary) and returns the code provenance type part
    #
    # == Parameters:
    # code::
    #   String
    #
    # == Returns:
    # code provenance type part of code
    # ex: file_provenance_part_from_code("outpatient:primary") returns "primary"
    #
    def code_provenance_part_from_code(code)
      code_split = code.split(CODE_SEPARATOR)

      return code_split[1] if code_split.length == 2 && !code_split[1].empty?
      return nil
    end
  end
end
