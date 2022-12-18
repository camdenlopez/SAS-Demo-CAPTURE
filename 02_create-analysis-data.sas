libname raw '~/CAPTURE/data/raw/sas';
libname analysis '~/CAPTURE/data/analysis';

%include '~/CAPTURE/code/00_formats.sas';

data demog(
    keep =
      ssid ctx_site age gender
      ethnicity race education);
  set raw.occ_form_000(
    rename =
      (dsstdat_ic = consent_dt
       dm_brthdatdt = birth_dt
       dm_sex = gender
       dm_ethnic = ethnicity
       dm_race_american_indian_or_ala = am_ind
       dm_race_asian = asian
       dm_race_black_or_african_ameri = bl_afr
       dm_race_native_hawaiian_or_oth = nt_haw
       dm_race_white = white
       dm_race_unk_prefer_not_to_answ = rac_na
       dm_race_unk_don_t_know = rac_dk
       sc_edlevel = education));
  
  age = (consent_dt - birth_dt) / 365.25;
  
  n_races =
    sum(am_ind, asian, bl_afr, nt_haw, white);
  select;
    when (rac_dk = 1 or
          rac_na = 1)  race = 7;
    when (n_races > 1) race = 6;
    when (white = 1)   race = 5;
    when (nt_haw = 1)  race = 4;
    when (bl_afr = 1)  race = 3;
    when (asian = 1)   race = 2;
    when (am_ind = 1)  race = 1;
    otherwise          race = .;
  end;
run;

proc sort data = demog;
  by ssid;
run;

proc print data=demog(obs=10);
run;

data capture;
  set raw.occ_form_011;
  
  select;
    when (cap_score = .)
      capture_pos = .;
    when (cap_score < 2)
      capture_pos = 0;
    when (cap_score >= 2 and cap_score <= 4)
      capture_pos = cap_ref;
    when (cap_score > 4)
      capture_pos = 1;
  end;
run;

proc sort data = capture;
  by ssid;
run;

proc sort
    data = raw.spirometry_upload
    out = spirom_in(keep = ssid pp_fvc pp_fev
                           fvc_pre_bd fev1_pre_bd
                           fvc_post_bd fev1_post_bd);
  by ssid;
run;

proc sort
    data = raw.occ_form_015(rename = (rse_che = acute_resp_illness))
    out = sympt_in(keep = ssid acute_resp_illness);
  by ssid;
run;

data copd(
    keep = ssid post_bd fev1_fvc fev1_pp acute_resp_illness
           clin_sig_copd spirom_copd mild_copd);
  merge spirom_in sympt_in;
  by ssid;
  
  post_bd = fev1_post_bd ne .;
  fev1_fvc_pre = fev1_pre_bd / fvc_pre_bd;
  fev1_pp_pre = 100 * fev1_pre_bd / pp_fev;
  fev1_fvc_post = fev1_post_bd / fvc_post_bd;
  fev1_pp_post = 100 * fev1_post_bd / pp_fev;
  
  if post_bd then do;
    fev1_fvc = fev1_fvc_post;
    fev1_pp = fev1_pp_post;
    spirom_copd = fev1_fvc_post < 0.7;
  end;
  else do;
    fev1_fvc = fev1_fvc_pre;
    fev1_pp = fev1_pp_pre;
    spirom_copd = fev1_fvc_pre < 0.65;
  end;
  
  clin_sig_copd =
    spirom_copd and
    (fev1_pp < 60 or acute_resp_illness = 1);
  
  mild_copd = spirom_copd and not clin_sig_copd;
run;

proc print data=copd(obs=10);
run;

proc freq data=copd;
  tables spirom_copd*mild_copd*clin_sig_copd / list missing;
run;

data analysis.patients;
  merge demog capture copd;
  by ssid;
  format
    gender gender.
    ethnicity ethnicity.
    race race.
    education education.
    capture_pos spirom_copd clin_sig_copd mild_copd yesno.;
run;

proc print data=analysis.patients(obs=10);
run;

libname zips xlsx '~/CAPTURE/data/raw/excel/CAPTURE practices and zipcodes.xlsx';

data pract_zips(rename=('Practice ID'n=ctx_site 'ZIP code'n=zip_code));
  set zips.Atrium
      zips.Duke
      zips.'High Plains'n
      zips.'LA Net'n
      zips.Oregon;
run;

proc sort data=pract_zips;
  by ctx_site;
run;

proc import datafile='~/CAPTURE/data/raw/excel/forhp-eligible-zips.xlsx'
            dbms=xlsx out=rural_zips;
run;

proc sort data=rural_zips;
  by zip_code;
run;

data pract;
  set analysis.patients(keep=ctx_site);
run;

proc sort data=pract nodupkey;
  by ctx_site;
run;

data pract;
  merge pract(in=in_pract)
        pract_zips;
  by ctx_site;
  if in_pract;
run;

proc sort data=pract;
  by zip_code;
run;

data analysis.practices;
  merge pract(in=in_pract)
        rural_zips(in=in_rural keep=zip_code);
  by zip_code;
  if in_pract;
  if in_rural then pract_location = 2;
  else             pract_location = 1;
  drop zip_code;
  
  format pract_location location.;
run;

proc sort data=analysis.practices;
  by ctx_site;
run;

proc print data=analysis.practices;
run;

proc freq data=analysis.practices;
  tables pract_location;
run;

data analysis.patients;
  merge analysis.patients(in=in_patients)
        analysis.practices;
  by ctx_site;
  if in_patients;
run;

%macro make_subgroup_counts(var=);
  proc means data=analysis.patients n completetypes nway;
    class &var clin_sig_copd capture_pos / preloadfmt;
    var age; /* Any numeric variable with no missing values */
    output out=analysis.cap_copd_&var(drop=_type_ _freq_) n=count;
  run;
%mend make_subgroup_counts;

%make_subgroup_counts(var=gender);
%make_subgroup_counts(var=ethnicity);
%make_subgroup_counts(var=race);
%make_subgroup_counts(var=pract_location);
%make_subgroup_counts(var=education);

proc print data=analysis.cap_copd_gender; run;
proc print data=analysis.cap_copd_ethnicity; run;
proc print data=analysis.cap_copd_race; run;
proc print data=analysis.cap_copd_pract_location; run;
proc print data=analysis.cap_copd_education; run;
