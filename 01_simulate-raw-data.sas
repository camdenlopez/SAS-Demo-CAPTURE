/***********************************************************************
 * Simulate raw study data, mimicking the actual study database tables *
 ***********************************************************************/

libname raw '~/CAPTURE/data/raw/sas';

/* Number of PBRNs */
%let n_pbrn = 7;

/* Total number of practices (study sites) */
%let n_practices = 100;

/* Patients to be enrolled per practice */
%let patients_per_practice = 50;

/* PBRN codes used in study site and patient identifiers */
%let pbrn_codes = A B C D E F G;

/* PBRN names corresponding to the codes above */
%let pbrn_names = Atrium|Duke|High Plains|LA Net|Oregon|UIC|Circuit Clinical;

/***********************************************
 * Preliminary table of practices and patients *
 ***********************************************/

/* Randomly assign each practice to a PBRN,
 * and enroll the target number of patients */
data enroll_init(keep=pbrn_id pbrn_code pract_id patient_id);
  length pbrn_code $1;
  
  do pract_id = 1 to &n_practices;
    pbrn_id = rand("Integer", 1, &n_pbrn);
    pbrn_code = scan("&pbrn_codes", pbrn_id);
    do patient_id = 1 to &patients_per_practice;
      output;
    end;
  end;
run;

proc sort data=enroll_init;
  by pbrn_id pract_id;
run;

/* To form the site and patient identifiers,
 * need to number the practices 1 to k within
 * each PBRN */
data enrollment(keep=ssid ctx_site);
  length ctx_site $3 ssid $9;
  set enroll_init;
  by pbrn_id pract_id;
  
  if first.pbrn_id then pract_num = 1;
  else if first.pract_id then pract_num + 1;
  
  /* Site identifier */
  ctx_site = cat(pbrn_code, put(pract_num, z2.));
  
  /* Patient identifier */
  ssid = cat(ctx_site, 'F', put(patient_id, z5.));
run;

proc sort data=enrollment;
  by ssid;
run;

/*******************************
 * OCC_FORM_000 (Demographics) *
 *******************************/

data raw.occ_form_000;
  set enrollment;
  
  /* Consent (enrollment) date */
  dsstdat_ic = '01APR2018'd + rand('Integer', 1, 1278);
  
  /* Age and date of birth */
  age_days = rand('Integer', round(365.25 * 45), round(365.25 * 80));
  dm_brthdatdt = dsstdat_ic - age_days;
  drop age_days;
  
  /* Gender */
  dm_sex = rand('Integer', 1, 2);
  length dm_sex_label $6;
  select(dm_sex);
    when (1) dm_sex_label = 'Male';
    when (2) dm_sex_label = 'Female';
  end;
  
  /* Ethnicity */
  dm_ethnic = rand('Uniform') < 0.13;
  dm_ethnic + 1;
  length dm_ethnic_label $23;
  select(dm_ethnic);
    when (1) dm_ethnic_label = 'Non-Hispanic/Non-Latino';
    when (2) dm_ethnic_label = 'Hispanic or Latino';
  end;
  
  /* Race (patient can select multiple) */
  dm_race_american_indian_or_ala = rand('Uniform') < 0.03;
  dm_race_asian                  = rand('Uniform') < 0.10;
  dm_race_black_or_african_ameri = rand('Uniform') < 0.30;
  dm_race_native_hawaiian_or_oth = rand('Uniform') < 0.01;
  dm_race_white                  = rand('Uniform') < 0.60;
  dm_race_unk_prefer_not_to_answ =
    dm_race_american_indian_or_ala = 0 and
    dm_race_asian = 0 and
    dm_race_black_or_african_ameri = 0 and
    dm_race_native_hawaiian_or_oth = 0 and
    dm_race_white = 0 and
    rand('Uniform') < 0.50;
  dm_race_unk_don_t_know =
    dm_race_american_indian_or_ala = 0 and
    dm_race_asian = 0 and
    dm_race_black_or_african_ameri = 0 and
    dm_race_native_hawaiian_or_oth = 0 and
    dm_race_white = 0 and
    dm_race_unk_prefer_not_to_answ = 0;
  
  /* Education */
  edlevel_u = rand('Uniform');
  length sc_edlevel_label $31;
  select;
    when (edlevel_u < 0.1)
      do;
        sc_edlevel = 1;
        sc_edlevel_label = 'Less than high school';
      end;
    when (edlevel_u < 0.3)
      do;
        sc_edlevel = 2;
        sc_edlevel_label = 'High school or GED';
      end;
    when (edlevel_u < 0.6)
      do;
        sc_edlevel = 3;
        sc_edlevel_label = 'Vocational or some college';
      end;
    when (edlevel_u < 0.9)
      do;
        sc_edlevel = 4;
        sc_edlevel_label = 'College degree';
      end;
    otherwise
      do;
        sc_edlevel = 5;
        sc_edlevel_label = 'Professional or graduate degree';
      end;
  end;
  drop edlevel_u;
  
  format dsstdat_ic dm_brthdatdt date9.;
run;

/*******************************
 * OCC_FORM_011 (CAPTURE Tool) *
 *******************************/

data raw.occ_form_011;
  set enrollment;
  
  /* CAPTURE questionnaire responses */
  cap1 = rand('Uniform') < 0.6;
  cap2 = rand('Uniform') < 0.4;
  cap3 = rand('Uniform') < 0.3;
  cap4 = rand('Uniform') < 0.2;
  
  cap5_u = rand('Uniform');
  if cap5_u < 0.05 then cap5 = 2;
  else if cap5_u < 0.2 then cap5 = 1;
  else cap5 = 0;
  drop cap5_u;
  
  /* CAPTURE score and PEFR (0=Normal, 1=Below threshold) */
  cap_score = sum(cap1, cap2, cap3, cap4, cap5);
  cap_ref = rand('Uniform') < 0.2;
run;

/*****************************
 * OCC_FORM_012 (Spirometry) *
 *****************************/

data raw.occ_form_012;
  set raw.occ_form_000(keep=ctx_site ssid dm_sex_label);
  
  /* Height in inches */
  if dm_sex_label = 'Male' then
    vs_orres_height = rand('Gaussian', 70, 3);
  else
    vs_orres_height = rand('Gaussian', 64, 3);
  vs_orres_height = round(vs_orres_height);
  drop dm_sex_label;
run;

/***********************************************
 * SPIROMETRY_UPLOAD (Spirometry measurements) *
 ***********************************************/

data raw.spirometry_upload;
  merge
    raw.occ_form_000(keep=
      ctx_site ssid dsstdat_ic dm_brthdatdt
      dm_sex_label dm_race_black_or_african_ameri)
    raw.occ_form_012(keep=ssid vs_orres_height);
  by ssid;
  
  /* Inputs for FVC and FEV1 prediction */
  age_y = (dsstdat_ic - dm_brthdatdt) / 365.25;
  height_cm = 2.54 * vs_orres_height;
  drop dsstdat_ic dm_brthdatdt vs_orres_height;
  
  /* Calculate predicted FVC and FEV1 using the NHANES equations */
  select;
    when (dm_sex_label = 'Male' and dm_race_black_or_african_ameri = 0)
      do;
        pp_fvc = -0.1933 + 0.00064 * age_y - 0.000269 * age_y**2 + 0.00018642 * height_cm**2;
        pp_fev =  0.5536 - 0.01303 * age_y - 0.000172 * age_y**2 + 0.00014098 * height_cm**2;
      end;
    when (dm_sex_label = 'Male' and dm_race_black_or_african_ameri = 1)
      do;
        pp_fvc = -0.1517 - 0.01821 * age_y + 0.00016643 * height_cm**2;
        pp_fev =  0.3411 - 0.02309 * age_y + 0.00013194 * height_cm**2;
      end;
    when (dm_sex_label = 'Female' and dm_race_black_or_african_ameri = 0)
      do;
        pp_fvc = -0.3560 + 0.01870 * age_y - 0.000382 * age_y**2 + 0.00014815 * height_cm**2;
        pp_fev =  0.4333 - 0.00361 * age_y - 0.000194 * age_y**2 + 0.00011496 * height_cm**2;
      end;
    when (dm_sex_label = 'Female' and dm_race_black_or_african_ameri = 1)
      do;
        pp_fvc = -0.3039 + 0.00536 * age_y - 0.000265 * age_y**2 + 0.00013606 * height_cm**2;
        pp_fev =  0.3433 - 0.01283 * age_y - 0.000097 * age_y**2 + 0.00010846 * height_cm**2;
      end;
  end;
  drop dm_sex_label dm_race_black_or_african_ameri age_y height_cm;
  
  /* Pre-bronchodilator measurements */
  fvc_pre_bd  = round(0.3 + 0.8 * pp_fvc + rand('Gaussian', 0, 0.5), 0.01);
  fev1_pre_bd = round(0.2 + 0.8 * pp_fev + rand('Gaussian', 0, 0.5), 0.01);
  
  /* Post-bronchodilator measurements collected
   * only if pre-BD spirometry was 'abnormal' */
  if fev1_pre_bd/fvc_pre_bd < 0.7 or fev1_pre_bd/pp_fev < 0.8 then
    do;
      fvc_post_bd  = round(0.15 + 0.7 * pp_fvc + rand('Gaussian', 0, 0.5), 0.01);
      fev1_post_bd = round(0.15 + 0.7 * pp_fev + rand('Gaussian', 0, 0.5), 0.01);
    end;
run;

/***************************************
 * OCC_FORM_015 (Respiratory Symptoms) *
 ***************************************/

data raw.occ_form_015;
  set enrollment;
  
  /* Over the last 12 months, have you had episodes of chest troubles
   * (cough, phlegm, or shortness of breath) requiring treatment with
   * antibiotics and/or steroids? */
  rse_che = rand('Uniform') < 0.1;
  length rse_che_label $3;
  select(rse_che);
    when (0) rse_che_label = 'No';
    when (1) rse_che_label = 'Yes';
  end;
run;

/************************
 * Study site ZIP codes *
 ************************/

data pract_zips;
  set enrollment(drop=ssid);
  by ctx_site;
  if first.ctx_site;
  
  length pbrn_code $1 pbrn_name $24;
  /* Get PBRN name to use as the Excel sheet name */
  pbrn_code = substr(ctx_site, 1, 1);
  pbrn_id = findw("&pbrn_codes", pbrn_code, ' ', 'e');
  pbrn_name = scan("&pbrn_names", pbrn_id, '|');
  
  /* Random ZIP code */
  zip = put(rand('Integer', 501, 99950), z5.);
run;

/* Create Excel file containing site ZIP codes */
libname zips xlsx '~/CAPTURE/data/raw/excel/CAPTURE practices and zipcodes.xlsx';

/* Output one sheet corresponding to one PBRN */
%macro write_pbrn_zips(pbrn_name=);
  data zips."&pbrn_name"n(rename=(ctx_site='Practice ID'n zip='Zip code'n));
    set pract_zips;
    if pbrn_name = "&pbrn_name";
    keep ctx_site zip;
  run;
%mend write_pbrn_zips;

/* Output sheets for all PBRNs */
%macro write_zips;
  %do pbrn = 1 %to &n_pbrn;
    %let name = %scan(&pbrn_names, &pbrn, |);
    %write_pbrn_zips(pbrn_name=&name);
  %end;
%mend write_zips;

%write_zips;
