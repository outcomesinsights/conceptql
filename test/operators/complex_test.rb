require_relative '../helper'

describe "complex combinations of operators" do
  it "should produce correct results" do
    measurement_period = {
      date_range: {
        start: '2000-01-01',
        end: '2099-12-31'
      }
    }
    initial_population = {
      during: {
        left: {
          time_window: [
            { person: true },
            { start: '+2y', end: '+17y' }
          ]
        },
        right: measurement_period
      }
    }

    initial_population_2 = {
      during: {
        left: measurement_period,
        right: {
          time_window: [
            { person: true },
            { start: '+2y', end: '+18y' }
          ]
        }
      }
    }

    ambulatory_cpts = {
      cpt: %w(99201 99202 99203 99204 99205 99212 99213 99214 99215 99218 99219 99220 99281 99282 99283 99284 99285 99381 99382 99383 99384 99385 99386 99387 99391 99392 99393 99394 99395 99396 99397)
    }

    pharyngitis_diagnoses = {
      union: [
        { icd9: %w(034.0 462) },
        { icd10: %w(J02.0 J02.9) }
      ]
    }

    ambulatory_encounters = {
      during: {
        left: {
          visit_occurrence: ambulatory_cpts
        },
        right: initial_population
      }
    }

    pharyngitis_medication = {
      intersect: [
        { rxnorm: %w(1013662 1013665 1043022 1043027 1043030 105152 105170 105171 108449 1113012 1148107 1244762 1249602 1302650 1302659 1302664 1302669 1302674 1373014 141962 141963 142118 1423080 1483787 197449 197450 197451 197452 197453 197454 197511 197512 197516 197517 197518 197595 197596) },
        { drug_type_concept: %w(38000175 38000176 38000177 38000179) }
      ]
    }

    ambulatory_encounters_with_pharyngitis = {
      intersect: [
        ambulatory_encounters,
        {
          visit_occurrence: pharyngitis_diagnoses
        }
      ]
    }

    ambulatory_encounter_with_meds = {
      during: {
        left: ambulatory_encounters_with_pharyngitis,
        right: {
          time_window: [
            pharyngitis_medication,
            { start: '-3d', end: 'start' }
          ]
        }
      }
    }

    meds_before_ambulatory_encounter = {
      during: {
        left: ambulatory_encounters,
        right: {
          time_window: [
            pharyngitis_medication,
            { start: '0', end: '30d' }
          ]
        }
      }
    }

    criteria_ids(
      except: {
        left: ambulatory_encounter_with_meds,
        right: meds_before_ambulatory_encounter
      }
    ).must_equal({})
    
    criteria_ids(
      during: {
        left: {
          except: {
            left: { icd9: '584' },
            right: {
              after: {
                left: { icd9: '584' },
                right: { icd9: [ 'V45.1', 'V56.0', 'V56.31', 'V56.32', 'V56.8' ] }
              }
            }
          }
        },
        right: {
          time_window: [
             { icd9_procedure: [ '39.95', '54.98' ] },
             { start: '0', end: '60d' }
          ]
        }
      }
    ).must_equal({})
    
    criteria_ids(
      intersect: [
        { place_of_service_code: '21' },
        { visit_occurrence: { icd9: %W(410.00 410.01) } },
        {
          visit_occurrence: {
            union: [
              { cpt: [ '0008T', '3142F', '43205', '43236', '76975', '91110', '91111' ] },
              { hcpcs: [ 'B4081', 'B4082' ] },
              { icd9_procedure: [ '42.22', '42.23', '44.13', '45.13', '52.21', '97.01' ] },
              { loinc: [ '16125-7', '17780-8', '40820-3', '50320-1', '5177-1', '7901-2' ] }
            ]
          }
        }
      ]
    ).must_equal({})

    criteria_ids(
      intersect: [
        { visit_occurrence: { icd9: '412' } },
        { visit_occurrence: { cpt: '99251' } }
      ]
    ).must_equal("visit_occurrence"=>[11416])

    criteria_ids(
      intersect: [
        {
          visit_occurrence: {
            icd9: '412'
          }
        },
        {
          visit_occurrence: {
            cpt: '99214'
          }
        }
      ]
    ).must_equal("visit_occurrence"=>[7812, 14055])

    criteria_ids(
      during: {
        left: { cpt: '99214' },
        right: {
          time_window: [
            { icd9: '412' },
            { start: '-30d', end: '30d' }
          ]
        }
      }
    ).must_equal("procedure_occurrence"=>[2025, 4524, 5866, 7133, 7893, 8571, 8642, 10445, 13814, 17530, 18068, 18818, 24602, 24610, 24954, 27482, 27501, 28522, 28544, 31518, 32083, 32898, 33003, 33434])

    criteria_ids(
      intersect: [
        { icd9: '412' },
        { complement: { condition_type: :inpatient_header } }
      ]
    ).must_equal("condition_occurrence"=>[1712, 1829, 4359, 5751, 6902, 7865, 8397, 10196, 10443, 10865, 13016, 13741, 17041, 17772, 17774, 18555, 19736, 20037, 21006, 21619, 21627, 22875, 22933, 24437, 24471, 24707, 24721, 24989, 25309, 25417, 25875, 25888, 27388, 28177, 28188, 30831, 31387, 31542, 31792, 32104, 32463, 32981])
  end
end
