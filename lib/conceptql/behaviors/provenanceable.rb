module ConceptQL
  module Provenanceable
    def to_concept_id(ctype)
      ctype = ctype.to_s.downcase
      position = nil
      if ctype =~ /(\d|_primary)$/ && ctype.count('_') > 1
        parts = ctype.split('_')
        position = parts.pop.to_i
        position -= 1 if ctype =~ /^outpatient/
        ctype = parts.join('_')
      end
      retval = concept_ids[ctype.to_sym]
      return retval[position] if position
      return retval
    end

    def concept_ids
      @concept_ids ||= Psych.load_file(config_dir + 'provenance.yml')
    end

    def config_dir
      Pathname.new(__FILE__).dirname + '..' + '..' + '..' + 'config'
    end
  end
end
