/********************************
 * Pre-specified Aim 1 analysis *
 ********************************/

libname analysis '~/CAPTURE/data/analysis';

%include '~/CAPTURE/code/00_formats.sas';

/**************************************************
 * PRIMARY OBJECTIVE                              *
 *                                                *
 * Overall sensitivity and specificity of CAPTURE *
 * for identifying clinically significant COPD    *
 **************************************************/

title 'PRIMARY OBJECTIVE';

title2 'Sensitivity of CAPTURE for detecting clinically significant COPD';
ods select OneWayFreqs BinomialCLs;
proc freq data = analysis.patients;
  tables capture_pos / nocum binomial(level='Yes' cl=exact);
  where clin_sig_copd;
run;

title2 'Specificity of CAPTURE for detecting clinically significant COPD';
ods select OneWayFreqs BinomialCLs;
proc freq data = analysis.patients;
  tables capture_pos / nocum binomial(level='No' cl=exact);
  where not clin_sig_copd;
run;

/************************
 * SECONDARY OBJECTIVES *
 ************************/

title 'SECONDARY OBJECTIVE';

/* Estimate sensitivity and specificity
 * within subgroups defined by 'var' */
%macro subgroup_sens_spec(var=);
  title2 'Sensitivity of CAPTURE for detecting clinically significant COPD';
  title3 "by &var";
  ods select OneWayFreqs BinomialCLs;
  proc freq data=analysis.cap_copd_&var(where=(clin_sig_copd=1));
    tables capture_pos / nocum binomial(level='Yes' cl=exact);
    by &var;
    weight count / zeros;
  run;
  
  title2 'Specificity of CAPTURE for detecting clinically significant COPD';
  title3 "by &var";
  ods select OneWayFreqs BinomialCLs;
  proc freq data=analysis.cap_copd_&var(where=(clin_sig_copd=0));
    tables capture_pos / nocum binomial(level='No' cl=exact);
    by &var;
    weight count / zeros;
  run;
%mend subgroup_sens_spec;

/* Estimate PPV and NPV within
 * subgroups defined by 'var' */
%macro subgroup_ppv_npv(var=);
  title2 'PPV of CAPTURE for detecting clinically significant COPD';
  title3 "by &var";
  ods select OneWayFreqs BinomialCLs;
  proc freq data=analysis.cap_copd_&var(where=(capture_pos=1));
    tables clin_sig_copd / nocum binomial(level='Yes' cl=exact);
    by &var;
    weight count / zeros;
  run;
  
  title2 'NPV of CAPTURE for detecting clinically significant COPD';
  title3 "by &var";
  ods select OneWayFreqs BinomialCLs;
  proc freq data=analysis.cap_copd_&var(where=(capture_pos=0));
    tables clin_sig_copd / nocum binomial(level='No' cl=exact);
    by &var;
    weight count / zeros;
  run;
%mend subgroup_ppv_npv;

/***************************************************
 * Sensitivity and specificity of CAPTURE          *
 * for identifying clinically significant COPD     *
 * in subgroups defined by gender, ethnicity/race, *
 * rural vs non-rural location, and education      *
 ***************************************************/

%subgroup_sens_spec(var=gender);
%subgroup_sens_spec(var=ethnicity);
%subgroup_sens_spec(var=race);
%subgroup_sens_spec(var=pract_location);
%subgroup_sens_spec(var=education);

/*************************************************
 * Positive and negative predictive values       *
 * (PPV, NPV) overall and in subgroups defined   *
 * by gender, ethnicity/race, rural vs non-rural *
 * location, and education                       *
 *************************************************/

title2 'PPV of CAPTURE for detecting clinically significant COPD';
ods select OneWayFreqs BinomialCLs;
proc freq data = analysis.patients;
  tables clin_sig_copd / nocum binomial(level='Yes' cl=exact);
  where capture_pos;
run;

title2 'NPV of CAPTURE for detecting clinically significant COPD';
ods select OneWayFreqs BinomialCLs;
proc freq data = analysis.patients;
  tables clin_sig_copd / nocum binomial(level='No' cl=exact);
  where not capture_pos;
run;

%subgroup_ppv_npv(var=gender);
%subgroup_ppv_npv(var=ethnicity);
%subgroup_ppv_npv(var=race);
%subgroup_ppv_npv(var=pract_location);
%subgroup_ppv_npv(var=education);
