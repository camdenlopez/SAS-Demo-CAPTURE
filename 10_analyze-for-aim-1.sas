libname analysis '~/CAPTURE/data/analysis';

%include '~/CAPTURE/code/00_formats.sas';

title 'Sensitivity of CAPTURE for detecting clinically significant COPD';
ods select OneWayFreqs BinomialCLs;
proc freq data = analysis.patients;
  tables capture_pos / nocum binomial(level='Yes' cl=exact);
  where clin_sig_copd;
run;

title 'Specificity of CAPTURE for detecting clinically significant COPD';
ods select OneWayFreqs BinomialCLs;
proc freq data = analysis.patients;
  tables capture_pos / nocum binomial(level='No' cl=exact);
  where not clin_sig_copd;
run;

%macro subgroup_sens_spec(var=);
  title 'Sensitivity of CAPTURE for detecting clinically significant COPD';
  title2 "by &var";
  ods select OneWayFreqs BinomialCLs;
  proc freq data=analysis.cap_copd_&var(where=(clin_sig_copd=1));
    tables capture_pos / nocum binomial(level='Yes' cl=exact);
    by &var;
    weight count / zeros;
  run;
  title 'Specificity of CAPTURE for detecting clinically significant COPD';
  title2 "by &var";
  ods select OneWayFreqs BinomialCLs;
  proc freq data=analysis.cap_copd_&var(where=(clin_sig_copd=0));
    tables capture_pos / nocum binomial(level='No' cl=exact);
    by &var;
    weight count / zeros;
  run;
%mend subgroup_sens_spec;

%subgroup_sens_spec(var=gender);
%subgroup_sens_spec(var=ethnicity);
%subgroup_sens_spec(var=race);
%subgroup_sens_spec(var=pract_location);
%subgroup_sens_spec(var=education);
