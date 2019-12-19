Sequel.migration do
  change do
    create_table(:patients) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :gender_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to the [concepts](#concepts) table for the unique gender of the patient", :key=>:id}
      Date :birth_date, {:comment=>"Date of birth (yyyy-mm-dd)"}
      foreign_key :race_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to the [concepts](#concepts) table for the unique race of the patient", :key=>:id}
      foreign_key :ethnicity_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to the [concepts](#concepts) table for the ethnicity of the patient", :key=>:id}
      foreign_key :address_id, :addresses, {:type=>:Bigint, :comment=>"FK reference to the place of residency for the patient in the location table, where the detailed address information is stored", :key=>:id}
      foreign_key :practitioner_id, :practitioners, {:type=>:Bigint, :comment=>"FK reference to the primary care practitioner the patient is seeing in the [practitioners](#practitioners) table", :key=>:id}
      String :patient_id_source_value, {:text=>true, :comment=>"Originial patient identifier defined in the source data", :null=>false}
    end

    create_table(:patient_details) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK reference to [patients](#patients) table", :null=>false, :key=>:id}
      Date :start_date, {:comment=>"Start date of record (yyyy-mm-dd)", :null=>false}
      Date :end_date, {:comment=>"Start date of record (yyyy-mm-dd)"}
      Float :value_as_number, {:comment=>"The patient detail result stored as a number, applicable to patient detail where the result is expressed as a numeric value"}
      String :value_as_string, {:text=>true, :comment=>"The patient detail result stored as a string, applicable to patient details where the result is expressed as verbatim text"}
      foreign_key :value_as_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the result associated with the patient detail", :key=>:id}
      foreign_key :patient_detail_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the code assigned to the record", :null=>false, :key=>:id}
      String :patient_detail_source_value, {:text=>true, :comment=>"Source code from raw data", :null=>false}
      foreign_key :patient_detail_vocabulary_id, :vocabularies, {:text=>true, :comment=>"Vocabulary the patient detail comes from", :null=>false, :type=>:Bigint, :key=>:id}
    end

    create_table(:practitioners) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      String :practitioner_name, {:text=>true, :comment=>"Practitioner's name, if available"}
      String :primary_identifier, {:text=>true, :comment=>"Primary practitioner identifier", :null=>false}
      String :primary_identifier_type, {:text=>true, :comment=>"Type of identifier specified in primary identifier field (UPIN, NPI, etc)", :null=>false}
      String :secondary_identifier, {:text=>true, :comment=>"Secondary practitioner identifier (Optional)"}
      String :secondary_identifier_type, {:text=>true, :comment=>"Type of identifier specified in secondary identifier field (UPIN, NPI, etc)"}
      foreign_key :specialty_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to an identifier in the [concepts](#concepts) table for specialty", :key=>:id}
      foreign_key :address_id, :addresses, {:type=>:Bigint, :comment=>"FK reference to the address of the location where the practitioner is practicing", :key=>:id}
      Date :birth_date, {:comment=>"Date of birth (yyyy-mm-dd)"}
      foreign_key :gender_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to an identifier in the [concepts](#concepts) table for the unique gender of the practitioner", :key=>:id}
    end

    create_table(:facilities) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      String :facility_name, {:text=>true, :comment=>"Facility name, if available"}
      String :primary_identifier, {:text=>true, :comment=>"Primary facility identifier", :null=>false}
      String :primary_identifier_type, {:text=>true, :comment=>"Type of identifier specified in primary identifier field (UPIN, NPI, etc)", :null=>false}
      String :secondary_identifier, {:text=>true, :comment=>"Secondary facility identifier (Optional)"}
      String :secondary_identifier_type, {:text=>true, :comment=>"Type of identifier specified in secondary identifier field (UPIN, NPI, etc)"}
      foreign_key :facility_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the facility type", :key=>:id}
      foreign_key :specialty_concept_id, :concepts, {:type=>:Bigint, :comment=>"A foreign key to an identifier in the [concepts](#concepts) table for specialty", :key=>:id}
      foreign_key :address_id, :addresses, {:type=>:Bigint, :comment=>"A foreign key to the address of the location of the facility", :key=>:id}
    end

    create_table(:collections) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK to reference to [patients](#patients) table", :null=>false, :key=>:id}
      Date :start_date, {:comment=>"Start date of record (yyyy-mm-dd)", :null=>false}
      Date :end_date, {:comment=>"End date of record (yyyy-mm-dd)", :null=>false}
      Float :duration, {:comment=>"Duration of collection. (e.g. hospitalization length of stay)"}
      Integer :duration_unit_concept_id, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the unit of duration (hours, days, weeks etc.)"}
      foreign_key :facility_id, :facilities, {:type=>:Bigint, :comment=>"FK reference to [facilities](#facilities) table", :key=>:id}
      foreign_key :admission_detail_id, :admission_details, {:type=>:Bigint, :comment=>"FK reference to [admission_details](#admission_details) table", :key=>:id}
      foreign_key :collection_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the type of collection this record represents", :key=>:id}
    end

    create_table(:contexts_practitioners) do
      foreign_key :context_id, :contexts, {:type=>:Bigint, :comment=>"FK reference to [contexts](#contexts) table", :null=>false, :key=>:id}
      foreign_key :practitioner_id, :practitioners, {:type=>:Bigint, :comment=>"FK reference to [practitioners](#practitioners) table", :null=>false, :key=>:id}
      foreign_key :role_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to the [concepts](#concepts) table representing roles [practitioners](#practitioners) can play in an encounter", :key=>:id}
      foreign_key :specialty_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the practitioner's specialty type for the services/diagnoses associated with this record", :key=>:id}
    end

    create_table(:contexts) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :collection_id, :collections, {:type=>:Bigint, :comment=>"FK reference to [collections](#collections) table", :null=>false, :key=>:id}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK to reference to [patients](#patients) table", :null=>false, :key=>:id}
      Date :start_date, {:comment=>"Start date of record (yyyy-mm-dd)", :null=>false}
      Date :end_date, {:comment=>"End date of record (yyyy-mm-dd)"}
      foreign_key :facility_id, :facilities, {:type=>:Bigint, :comment=>"FK reference to [facilities](#facilities) table", :key=>:id}
      foreign_key :care_site_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the care site type within the facility", :key=>:id}
      foreign_key :pos_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the place of service associated with this record", :key=>:id}
      foreign_key :source_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the file name (e.g MEDPAR). If data represents a subset of a file, concatenate the name of the file used and subset  (e.g MEDPAR_SNF)", :null=>false, :key=>:id}
      foreign_key :service_specialty_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the specialty type for the services/diagnoses associated with this record", :key=>:id}
      foreign_key :record_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the type of [contexts](#contexts) the record represents (line, claim, etc.)", :null=>false, :key=>:id}
    end

    create_table(:clinical_codes) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :collection_id, :collections, {:type=>:Bigint, :comment=>"FK reference to [collections](#collections) table", :null=>false, :key=>:id}
      foreign_key :context_id, :contexts, {:type=>:Bigint, :comment=>"FK reference to [contexts](#contexts) table", :null=>false, :key=>:id}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK reference to [patients](#patients) table", :null=>false, :key=>:id}
      Date :start_date, {:comment=>"Start date of record (yyyy-mm-dd)", :null=>false}
      Date :end_date, {:comment=>"End date of record (yyyy-mm-dd)", :null=>false}
      foreign_key :clinical_code_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the code assigned to the record", :null=>false, :key=>:id}
      Integer :quantity, {:type=>:Bigint, :comment=>"Quantity, if available (e.g., procedures)"}
      Integer :seq_num, {:comment=>"The sequence number for the variable assigned (e.g. dx3 gets sequence number 3)"}
      foreign_key :provenance_concept_id, :concepts, {:type=>:Bigint, :comment=>"Additional type information (ex: primary, admitting, problem list, etc)", :key=>:id}
      String :clinical_code_source_value, {:text=>true, :comment=>"Source code from raw data", :null=>false}
      foreign_key :clinical_code_vocabulary_id, :vocabularies, {:text=>true, :comment=>"FK reference to the vocabulary the clinical code comes from", :null=>false, :type=>:Bigint, :key=>:id}
      foreign_key :measurement_detail_id, :measurement_details, {:type=>:Bigint, :comment=>"FK reference to [measurement_details](#measurement_details) table", :key=>:id}
      foreign_key :drug_exposure_detail_id, :drug_exposure_details, {:type=>:Bigint, :comment=>"FK reference to [drug_exposure_details](#drug_exposure_details) table", :key=>:id}
    end

    create_table(:measurement_details) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK reference to [patients](#patients) table", :null=>false, :key=>:id}
      Float :result_as_number, {:comment=>"The observation result stored as a number, applicable to observations where the result is expressed as a numeric value"}
      String :result_as_string, {:text=>true, :comment=>"The observation result stored as a string, applicable to observations where the result is expressed as verbatim text"}
      foreign_key :result_as_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the result associated with the detail_concept_id (e.g., positive/negative, present/absent, low/high, etc.)", :key=>:id}
      foreign_key :result_modifier_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for result modifier (=, <, >, etc.)", :key=>:id}
      foreign_key :unit_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the measurement units (e.g., mmol/L, mg/dL, etc.)", :key=>:id}
      Float :normal_range_low, {:comment=>"Lower bound of the normal reference range assigned by the laboratory"}
      Float :normal_range_high, {:comment=>"Upper bound of the normal reference range assigned by the laboratory"}
      foreign_key :normal_range_low_modifier_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for result modifier (=, <, >, etc.)", :key=>:id}
      foreign_key :normal_range_high_modifier_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for result modifier (=, <, >, etc.)", :key=>:id}
    end

    create_table(:drug_exposure_details) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK to reference to [patients](#patients) table", :null=>false, :key=>:id}
      Integer :refills, {:comment=>"The number of refills after the initial prescription; the initial prescription is not counted (i.e., values start with 0)"}
      Integer :days_supply, {:comment=>"The number of days of supply as recorded in the original prescription or dispensing record"}
      Float :number_per_day, {:comment=>"The number of pills taken per day"}
      foreign_key :dose_form_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the form of the drug (capsule, injection, etc.)", :key=>:id}
      foreign_key :dose_unit_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the units in which the dose_value is expressed", :key=>:id}
      foreign_key :route_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for route in which drug is given", :key=>:id}
      Float :dose_value, {:comment=>"Numeric value for the dose of the drug"}
      String :strength_source_value, {:text=>true, :comment=>"Drug strength as reported in the raw data. This can include both dose value and units"}
      String :ingredient_source_value, {:text=>true, :comment=>"Ingredient/Generic name of drug as reported in the raw data"}
      String :drug_name_source_value, {:text=>true, :comment=>"Product/Brand name of drug as reported in the raw data"}
    end

    create_table(:payer_reimbursements) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record"}
      foreign_key :context_id, :contexts, {:type=>:Bigint, :comment=>"FK reference to context table", :null=>false, :key=>:id}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK to reference to [patients](#patients) table", :null=>false, :key=>:id}
      foreign_key :clinical_code_id, :clinical_codes, {:type=>:Bigint, :comment=>"FK reference to [clinical_codes](#clinical_codes) table to be used if a specific code is the direct cause for the reimbursement", :key=>:id}
      foreign_key :currency_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the 3-letter code used to delineate international currencies (e.g., USD = US Dollar)", :null=>false, :key=>:id}
      Float :total_charged, {:comment=>"The total amount charged by the provider of the good/service (e.g. hospital, physician pharmacy, dme provider) billed to a payer. This information is usually provided in claims data."}
      Float :total_paid, {:comment=>"The total amount paid from all payers for the expenses of the service/device/drug. This field is calculated using the following formula: paid_by_payer + paid_by_patient + paid_by_primary. In claims data, this field is considered the calculated field the payer expects the provider to get reimbursed for the service/device/drug from the payer and from the patient, based on the payer's contractual obligations."}
      Float :paid_by_payer, {:comment=>"The amount paid by the Payer for the service/device/drug. In claims data, generally there is one field representing the total payment from the payer for the service/device/drug. However, this field could be a calculated field if the source data provides separate payment information for the ingredient cost and the dispensing fee. If the paid_ingredient_cost or paid_dispensing_fee fields are populated with nonzero values, the paid_by_payer field is calculated using the following formula: paid_ingredient_cost + paid_dispensing_fee. If there is more than one Payer in the source data, several cost records indicate that fact. The Payer reporting this reimbursement should be indicated under the payer_plan_id field."}
      Float :paid_by_patient, {:comment=>"The total amount paid by the patient as a share of the expenses. This field is most often used in claims data to report the contracted amount the patient is responsible for reimbursing the provider for said service/device/drug. This is a calculated field using the following formula: paid_patient_copay + paid_patient_coinsurance + paid_patient_deductible. If the source data has actual patient payments (e.g. the patient payment is not a derivative of the payer claim and there is verification the patient paid an amount to the provider), then the patient payment should have it's own cost record with a payer_plan_id set to 0 to indicate the payer is actually the patient, and the actual patient payment should be noted under the total_paid field. The paid_by_patient field is only used for reporting a patient's responsibility reported on an insurance claim."}
      Float :paid_patient_copay, {:comment=>"The amount paid by the patient as a fixed contribution to the expenses. paid_patient_copay does contribute to the paid_by_patient variable. The paid_patient_copay field is only used for reporting a patient's copay amount reported on an insurance claim."}
      Float :paid_patient_coinsurance, {:comment=>"The amount paid by the patient as a joint assumption of risk. Typically, this is a percentage of the expenses defined by the Payer Plan after the patient's deductible is exceeded. paid_patient_coinsurance does contribute to the paid_by_patient variable. The paid_patient_coinsurance field is only used for reporting a patient's coinsurance amount reported on an insurance claim."}
      Float :paid_patient_deductible, {:comment=>"The amount paid by the patient that is counted toward the deductible defined by the Payer Plan. paid_patient_deductible does contribute to the paid_by_patient variable. The paid_patient_deductible field is only used for reporting a patient's deductible amount reported on an insurance claim."}
      Float :paid_by_primary, {:comment=>"The amount paid by a primary Payer through the coordination of benefits. paid_by_primary does contribute to the total_paid variable. The paid_by_primary field is only used for reporting a patient's primary insurance payment amount reported on the secondary payer insurance claim. If the source data has actual primary insurance payments (e.g. the primary insurance payment is not a derivative of the payer claim and there is verification another insurance company paid an amount to the provider), then the primary insurance payment should have it's own cost record with a payer_plan_id set to the applicable payer, and the actual primary insurance payment should be noted under the paid_by_payer field."}
      Float :paid_ingredient_cost, {:comment=>"The amount paid by the Payer to a pharmacy for the drug, excluding the amount paid for dispensing the drug. paid_ingredient_cost contributes to the paid_by_payer field if this field is populated with a nonzero value."}
      Float :paid_dispensing_fee, {:comment=>"The amount paid by the Payer to a pharmacy for dispensing a drug, excluding the amount paid for the drug ingredient. paid_dispensing_fee contributes to the paid_by_payer field if this field is populated with a nonzero value."}
      Integer :information_period_id, {:type=>:Bigint, :comment=>"FK reference to the [information_periods](#information_periods) table"}
      Float :amount_allowed, {:comment=>"The contracted amount agreed between the payer and provider. This information is generally available in claims data. This is similar to the total_paid amount in that it shows what the payer expects the provider to be reimbursed after the payer and patient pay. This differs from the total_paid amount in that it is not a calculated field, but a field available directly in claims data. Use case: This will capture non-covered services. Non-covered services are indicated by an amount allowed and patient responsibility variables (copay, coinsurance, deductible) will be equal $0 in the source data. This means the patient is responsible for the total_charged value. The amount_allowed field is payer specific and the payer should be indicated by the payer_plan_id field."}
    end

    create_table(:costs) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :context_id, :contexts, {:type=>:Bigint, :comment=>"FK reference to context table", :null=>false, :key=>:id}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK reference to [patients](#patients) table", :null=>false, :key=>:id}
      foreign_key :clinical_code_id, :clinical_codes, {:type=>:Bigint, :comment=>"FK reference to [clinical_codes](#clinical_codes) table to be used if a specific code is the direct cause for the reimbursement", :key=>:id}
      foreign_key :currency_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the 3-letter code used to delineate international currencies (e.g., USD = US Dollar)", :null=>false, :key=>:id}
      String :cost_base, {:text=>true, :comment=>"Defines the basis for the cost in the table (e.g., 2013 for a specific cost-to-charge ratio, or a specific cost from an external cost", :null=>false}
      Float :value, {:comment=>"Cost value", :null=>false}
      foreign_key :value_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table to concept that defines the type of economic information in the value field (e.g., cost-to-charge ratio, calculated cost, reported cost)", :null=>false, :key=>:id}
    end

    create_table(:addresses) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      String :address_1, {:text=>true, :comment=>"Typically used for street address"}
      String :address_2, {:text=>true, :comment=>"Typically used for additional detail such as building, suite, floor, etc."}
      String :city, {:text=>true, :comment=>"The city field as it appears in the source data"}
      String :state, {:text=>true, :comment=>"The state field as it appears in the source data"}
      String :zip, {:text=>true, :comment=>"The zip or postal code"}
      String :county, {:text=>true, :comment=>"The county, if available"}
      String :census_tract, {:text=>true, :comment=>"The census tract if available"}
      String :hsa, {:text=>true, :comment=>"The Health Service Area, if available (originally defined by the National Center for Health Statistics)"}
      String :country, {:text=>true, :comment=>"The country if necessary"}
    end

    create_table(:deaths) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK reference to [patients](#patients) table", :null=>false, :key=>:id}
      Date :date, {:comment=>"Date of death (yyyy-mm-dd)", :null=>false}
      foreign_key :cause_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for cause of death (typically ICD-9 or ICD-10 code)", :key=>:id}
      foreign_key :cause_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the type of cause of death (e.g. primary, secondary, etc. )", :key=>:id}
      foreign_key :practitioner_id, :practitioners, {:type=>:Bigint, :comment=>"FK reference to [practitioners](#practitioners) table", :key=>:id}
    end

    create_table(:information_periods) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK reference to [patients](#patients) table", :null=>false, :key=>:id}
      Date :start_date, {:comment=>"Start date of record (yyyy-mm-dd)", :null=>false}
      Date :end_date, {:comment=>"End date of record (yyyy-mm-dd)", :null=>false}
      foreign_key :information_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the information type (e.g., insurance coverage, hospital data, up-to-standard date)", :null=>false, :key=>:id}
    end

    create_table(:admission_details) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record", :null=>false}
      foreign_key :patient_id, :patients, {:type=>:Bigint, :comment=>"FK reference to [patients](#patients) table", :null=>false, :key=>:id}
      Date :admission_date, {:comment=>"Date of admission (yyyy-mm-dd)", :null=>false}
      Date :discharge_date, {:comment=>"Date of discharge (yyyy-mm-dd)", :null=>false}
      foreign_key :admit_source_concept_id, :concepts, {:type=>:Bigint, :comment=>"Database specific code indicating source of admission (e.g., ER visit, transfer, etc.)", :key=>:id}
      foreign_key :discharge_location_concept_id, :concepts, {:type=>:Bigint, :comment=>"Database specific code indicating discharge location (e.g., death, home, transfer, long-term care, etc.)", :key=>:id}
      foreign_key :admission_type_concept_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table representing the type of admission the record is (Emergency, Elective, etc.)", :key=>:id}
    end

    create_table(:concepts) do
      primary_key :id, {:type=>:Bigint, :comment=>"Surrogate key for record (this is the concept_id)", :null=>false}
      foreign_key :vocabulary_id, :vocabularies, {:text=>true, :comment=>"FK reference to the vocabularies table for the vocabulary associated with the concept (see OMOP or UMLS)", :null=>false, :type=>:Bigint, :key=>:id}
      String :concept_code, {:text=>true, :comment=>"Actual code as text string from the source vocabulary (e.g., \"410.00\" for ICD-9)", :null=>false}
      String :concept_text, {:text=>true, :comment=>"Text descriptor associated with the concept_code", :null=>false}
    end

    create_table(:vocabularies) do
      String :id, {:text=>true, :primary_key=>true, :comment=>"Short name of the vocabulary which acts as a natural key for record", :null=>false}
      String :vocabulary_name, {:text=>true, :comment=>"Full name of the vocabulary", :null=>false}
      String :domain, {:text=>true, :comment=>"Domain to which the majority of the vocabulary is assigned"}
      Integer :concepts_count, {:type=>:Bigint, :comment=>"Number of row in the [concepts](#concepts) table assigned to this vocabulary"}
      TrueClass :is_clinical_vocabulary, {:comment=>"Are concepts from this vocabulary stored in [clinical_codes](#clinical_codes)?"}
    end

    create_table(:mappings) do
      foreign_key :concept_1_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the source concept", :null=>false, :key=>:id}
      String :relationship_id, {:text=>true, :comment=>"The type or nature of the relationship (e.g., \"is_a\")", :null=>false}
      foreign_key :concept_2_id, :concepts, {:type=>:Bigint, :comment=>"FK reference to [concepts](#concepts) table for the destination concept", :null=>false, :key=>:id}
    end
  end
end
