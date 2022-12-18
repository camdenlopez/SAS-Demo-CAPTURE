proc format;
  value gender
    1='Male'
    2='Female';
  value ethnicity
    1='Non-Hispanic/Non-Latino'
    2='Hispanic or Latino';
  value race
    1='American Indian or Alaska Native'
    2='Asian'
    3='Black or African American'
    4='Native Hawaiian or Other Pacific Islander'
    5='White'
    6='Multiple races'
    7="Don't know/Prefer not to answer";
  value education
    1='Less than high school'
    2='High school or GED'
    3='Vocational school or some college'
    4='College degree'
    5='Professional or graduate degree'
    77='Prefer not to answer';
  value yesno
    0='No'
    1='Yes';
  value location
    1='Non-rural'
    2='Rural';
run;