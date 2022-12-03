libname analysis '~/CAPTURE/data/analysis';

title 'Sensitivity of CAPTURE for detecting clinically significant COPD';
ods select OneWayFreqs BinomialCLs;
proc freq data = analysis.patients;
  tables capture_pos / nocum binomial(level='1' cl=exact);
  where clin_sig_copd;
run;

title 'Specificity of CAPTURE for detecting clinically significant COPD';
ods select OneWayFreqs BinomialCLs;
proc freq data = analysis.patients;
  tables capture_pos / nocum binomial(level='0' cl=exact);
  where not clin_sig_copd;
run;
