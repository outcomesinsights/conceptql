module ConceptQL
  module Provenanceable

    def self.included(base)
      base.require_column :file_provenance_type
      base.require_column :code_provenance_type
    end

    FILE_PROVENANCE_TYPES_VOCAB = "JIGSAW_FILE_PROVENANCE_TYPE"
    CODE_PROVENANCE_TYPES_VOCAB = "JIGSAW_CODE_PROVENANCE_TYPE"

    BASE_FILE_PROVENANCE_TYPES = %w(
          carrier_claim
          inpatient
          outpatient
          prescription_drug
          demographics
        )

    BASE_CODE_PROVENANCE_TYPES = %w(
      primary
      first
      admitting
      primary_or_first
    )

    def to_concept_id(ctype)
      ctype = ctype.to_s.downcase
      return ctype.to_i unless ctype.to_i.zero?
      position = nil
      if ctype =~ /(\d|_primary)$/ && ctype.count('_') > 1
        parts = ctype.split('_')
        position = parts.pop.to_i
        position -= 1 if needs_adjustment?(ctype)
        ctype = parts.join('_')
      end
      retval = concept_ids[ctype.to_sym]
      return retval[position] if position
      return retval
    end

    def build_where_from_codes(codes)

      codes = codes.each_with_object({concept_codes: [], concept_ids: []}) {|code, h|
        h[:concept_codes] << code.to_s.downcase if code.to_i.zero?
        h[:concept_ids] << code.to_i if !code.to_i.zero?
      }


      build_code_concept_ids(codes[:concept_codes])

      w = []

      w = concept_ids_by_code(codes[:concept_codes]).each_with_object([]){|code, arr|
        file_prov_concept_ids = code[1][FILE_PROVENANCE_TYPES_VOCAB]
        code_prov_concept_ids = code[1][CODE_PROVENANCE_TYPES_VOCAB]

        res = {}

        if gdm?
          res[:file_provenance_type] = file_prov_concept_ids if file_prov_concept_ids
          res[:code_provenance_type] = code_prov_concept_ids if code_prov_concept_ids
        else
          # For omop get concept ids that are both in file and code if both contain values
          res[:code_provenance_type] = (file_prov_concept_ids & code_prov_concept_ids) if !file_prov_concept_ids.to_a.empty? & !code_prov_concept_ids.to_a.empty?
          res[:code_provenance_type] = file_prov_concept_ids if !file_prov_concept_ids.to_a.empty? & code_prov_concept_ids.to_a.empty?
          res[:code_provenance_type] = code_prov_concept_ids if !code_prov_concept_ids.to_a.empty? & file_prov_concept_ids.to_a.empty?
        end
        arr << res
      }

      # If there are raw concept_id's check either/or file/code provenance columns
      w += [{file_provenance_type: codes[:concept_ids]}, {code_provenance_type: codes[:concept_ids]}] if codes[:concept_ids]

      return Sequel.|(*w)
    end

    def concept_ids_by_code(codes)
      codes.map{|code|
        code = code.to_s.downcase

        file_type = file_provenance_part_from_code(code)
        code_type = code_provenance_part_from_code(code)

        file_type_ids = std_code_concept_ids(file_type)
        code_type_ids = std_code_concept_ids(code_type)

        [code, {FILE_PROVENANCE_TYPES_VOCAB => file_type_ids,
                CODE_PROVENANCE_TYPES_VOCAB => code_type_ids}]
      }.to_h
    end

    def build_code_concept_ids(codes)
      @std_code_concept_ids ||= get_std_code_concept_ids(codes)
    end

    def std_code_concept_ids(code)
      @std_code_concept_ids[code]
    end

    def std_codes_by_prov_type(codes)
      @std_codes_by_prov_type ||= codes.each_with_object({FILE_PROVENANCE_TYPES_VOCAB => [], CODE_PROVENANCE_TYPES_VOCAB => []}){|code, h|
        file_types = file_provenance_part_from_code(code)
        code_types = code_provenance_part_from_code(code)

        h[FILE_PROVENANCE_TYPES_VOCAB] << file_types if file_types
        h[CODE_PROVENANCE_TYPES_VOCAB] << code_types if code_types
      }
    end

    def get_std_code_concept_ids(codes)
      std_codes = std_codes_by_prov_type(codes)

      file_type_codes = std_codes[FILE_PROVENANCE_TYPES_VOCAB].uniq
      code_type_codes = std_codes[CODE_PROVENANCE_TYPES_VOCAB].uniq

      conditions = []
      conditions << {vocabulary_id: FILE_PROVENANCE_TYPES_VOCAB, concept_code: file_type_codes} unless file_type_codes.to_a.empty?
      conditions << {vocabulary_id: CODE_PROVENANCE_TYPES_VOCAB, concept_code: code_type_codes} unless code_type_codes.to_a.empty?

      if !conditions.empty?
        db = lexicon.db[:concepts]

        db = db.where(Sequel.|(*conditions))

        db = db.from_self(alias: :c).join(:mappings, concept_id_1: :id)

        res = db.select_hash_groups(Sequel[:c][:concept_code], [Sequel[:mappings][:concept_id_1], Sequel[:mappings][:concept_id_2]])

        res.transform_values{|v| v.flatten.uniq}
      else
        return {}
      end
    end

    def file_provenance_part_from_code(code)
      return BASE_FILE_PROVENANCE_TYPES.select { |e| code.include?(e) }.uniq.first
    end

    def code_provenance_part_from_code(code)
      return BASE_CODE_PROVENANCE_TYPES.select { |e| code.include?(e) }.uniq.first
    end
  end
end
