module ConceptQL
  module Provenanceable

    def self.included(base)
      base.require_column :file_provenance_type
      base.require_column :code_provenance_type
    end

    FILE_PROVENANCE_TYPES_VOCAB = "JIGSAW_FILE_PROVENANCE_TYPE"
    CODE_PROVENANCE_TYPES_VOCAB = "JIGSAW_CODE_PROVENANCE_TYPE"

    # Creates hash of provenance type concept codes by vocabulary_id (JIGSAW_FILE_PROVENANCE_TYPE, JIGSAW_CODE_PROVENANCE_TYPE)
    #
    # == Returns:
    # Hash with provenance type concept_codes by vocabulary_id
    #
    def provenance_types
      @provenance_types ||= lexicon.lexicon_db[:concepts].where(vocabulary_id: [FILE_PROVENANCE_TYPES_VOCAB,CODE_PROVENANCE_TYPES_VOCAB]).select_hash_groups(:vocabulary_id, [:concept_code, :id])
    end

    def base_file_provenance_types
      @base_file_provenance_types ||= provenance_types[FILE_PROVENANCE_TYPES_VOCAB].to_h
    end

    def base_code_provenance_types
      @base_code_provenance_types ||= provenance_types[CODE_PROVENANCE_TYPES_VOCAB].to_h
    end

    # Creates hash of mixed provenance type codes (ex: inpatient_primary) with the key set to the code and the value a hash that splits out the file type code and code type code
    #
    # Makes all combinations of base file provenance type and base code provenance type into new codes of the form <file prov code>_<code prov code>
    #
    # == Returns:
    # Hash with code as key and value hash with code split into file_type and code_type
    #
    # {
    #  inpatient_primary: {file_type: "inpatient", code_type: "primary" },
    #  outpatient_primary: {file_type: "outpatient", code_type: "primary" }
    # }
    def mixed_provenance_types
      @mixed_provenance_types ||= base_file_provenance_types.keys.product(base_code_provenance_types.keys).map{|c| [c.join(CODE_SEPARATOR),{file_type: c[0], code_type: c[1]}] }.to_h
    end

    # Creates array of all unique combinations of allowed file provenance and code provenance types
    #
    # == Returns:
    # Array with every combination of file and code type separated by "_"
    #
    def allowed_provenance_types
      @allowed_provenance_types ||= allowed_provenance_types_by_source.flat_map(&:last)
    end

    # Creates array of all unique combinations of allowed file provenance and code provenance types
    #
    # == Returns:
    # Array with every combination of file and code type separated by "_"
    #
    def allowed_provenance_types_by_source
      @allowed_provenance_types_by_source ||= {
        file_only: base_file_provenance_types,
        code_only: base_code_provenance_types,
        mixed: mixed_provenance_types.map(&:first)
      }
    end

    # Creates array of all unique combinations of allowed file provenance and code provenance types
    #
    # Makes all combinations of base file provenance type and base code provenance type into new codes of the form <file prov code>_<code prov code>
    #
    # == Returns:
    # Hash with code as key and value hash with code split into file_type and code_type
    #
    # {
    #  inpatient_primary: {file_type: "inpatient", code_type: "primary" },
    #  outpatient_primary: {file_type: "outpatient", code_type: "primary" }
    # }
    def mixed_provenance_types
      @mixed_provenance_types ||= base_file_provenance_types.product(base_code_provenance_types).map{|c| [c.join("_"),{file_type: c[0], code_type: c[1]}] }.to_h
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
    def build_where_from_codes(codes)

      codes = codes.each_with_object({concept_codes: [], concept_ids: []}) {|code, h|
        h[:concept_codes] << code.to_s.downcase if code.to_i.zero?
        h[:concept_ids] << code.to_i if !code.to_i.zero?
      }

      build_std_code_concept_ids(codes[:concept_codes])

      w = []

      w = concept_ids_by_code(codes[:concept_codes]).each_with_object([]){|code, arr|
        file_prov_concept_ids = code[1][FILE_PROVENANCE_TYPES_VOCAB].to_a
        code_prov_concept_ids = code[1][CODE_PROVENANCE_TYPES_VOCAB].to_a

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

      # If there are raw concept_id's check either/or file/code provenance columns
      w += [{file_provenance_type: codes[:concept_ids]}, {code_provenance_type: codes[:concept_ids]}] unless codes[:concept_ids].to_a.empty?

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
        code = code.to_s.downcase

        file_type = file_provenance_part_from_code(code)
        code_type = code_provenance_part_from_code(code)

        h = {}

        h[FILE_PROVENANCE_TYPES_VOCAB] = std_code_concept_ids[file_type]
        h[CODE_PROVENANCE_TYPES_VOCAB] = std_code_concept_ids[code_type]

        [code, h]
      }.to_h
    end

    def build_std_code_concept_ids(codes)
      @std_code_concept_ids = get_std_code_concept_ids(codes)
    end

    def std_code_concept_ids
      @std_code_concept_ids
    end

    # Takes list of codes (inpatient, outpatient_primary, etc) and splits them into file and code provenance types
    #
    # == Parameters:
    # codes::
    #   Array of standard provenance codes to get related concept ids split by file and code type provenance
    #
    # == Returns:
    # A hash in the form:
    # {
    #  JIGSAW_FILE_PROVENANCE_TYPE: ['inpatient', 'ouptient'],
    #  JIGSAW_CODE_PROVENANCE_TYPE: ['primary']
    # }
    #
    def std_codes_by_prov_type(codes)
      codes.each_with_object({FILE_PROVENANCE_TYPES_VOCAB => [], CODE_PROVENANCE_TYPES_VOCAB => []}){|code, h|
        file_types = file_provenance_part_from_code(code)
        code_types = code_provenance_part_from_code(code)

        h[FILE_PROVENANCE_TYPES_VOCAB] << file_types if file_types
        h[CODE_PROVENANCE_TYPES_VOCAB] << code_types if code_types
      }
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
    #  inpatient: [related concept ids],
    #  outpatient: [related concept ids],
    #  primary: [related concept ids]
    # }
    #
    def get_std_code_concept_ids(codes)
      std_codes = std_codes_by_prov_type(codes)

      file_type_codes = std_codes[FILE_PROVENANCE_TYPES_VOCAB].uniq
      code_type_codes = std_codes[CODE_PROVENANCE_TYPES_VOCAB].uniq

      conditions = []
      conditions << {vocabulary_id: FILE_PROVENANCE_TYPES_VOCAB, concept_code: file_type_codes} unless file_type_codes.to_a.empty?
      conditions << {vocabulary_id: CODE_PROVENANCE_TYPES_VOCAB, concept_code: code_type_codes} unless code_type_codes.to_a.empty?

      if !conditions.empty?
        db = lexicon.lexicon_db[:concepts]

        db = db.where(Sequel.|(*conditions))

        db = db.from_self(alias: :c).join(:ancestors, ancestor_id: :id)

        res = db.select_hash_groups(Sequel[:c][:concept_code], [Sequel[:ancestors][:ancestor_id], Sequel[:ancestors][:descendant_id]])

        res.transform_values{|v| v.flatten.uniq}
      else
        return {}
      end
    end

    # Takes a code (ex: outpatient_primary) and returns the corresponding BASE_FILE_PROVENANCE_TYPE of the code
    #
    # == Parameters:
    # code::
    #   String
    #
    # == Returns:
    # The longest string from base_file_provenance_types that is found within code.
    # ex: file_provenance_part_from_code("outpatient_primary") returns "outpatient"
    #
    def file_provenance_part_from_code(code)
      return code if allowed_provenance_types_by_source[:file_only].include?(code)
      return mixed_provenance_types[code][:file_type] if mixed_provenance_types[code]
      return nil
    end

    # Takes a code (ex: outpatient_primary) and returns the corresponding BASE_CODE_PROVENANCE_TYPE of the code
    #
    # == Parameters:
    # code::
    #   String
    #
    # == Returns:
    # The longest string from base_code_provenance_types that is found within code
    # ex: file_provenance_part_from_code("outpatient_primary") returns "primary"
    #
    def code_provenance_part_from_code(code)
      return code if allowed_provenance_types_by_source[:code_only].include?(code)
      return mixed_provenance_types[code][:code_type] if mixed_provenance_types[code]
      return nil
    end
  end
end
