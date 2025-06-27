#include <Rinternals.h>
#include <R.h>

/* The progress bar */
static SEXP pb;

/* Save the progress bar */
SEXP storePB(SEXP tpb) {
  pb = tpb;
  return(R_NilValue);
}

/* Set Progress bar to value */
void F77_SUB(setpb)(int *val) {
  SEXP s, t;
  /* printf("%d\n", *val); */
  /* t = s = PROTECT(allocList(3)); */
  /* SET_TYPEOF(s, LANGSXP); */
  t = s = PROTECT(LCONS(R_NilValue, Rf_allocList(2)));
  SETCAR(t, install("setTxtProgressBar")); t = CDR(t);
  SETCAR(t,  pb); SET_TAG(t, install("pb"));  t = CDR(t);
  SETCAR(t,  ScalarInteger(*val)); SET_TAG(t, install("value"));
  eval(s, R_GetCurrentEnv());
  UNPROTECT(1);
}

/* /\* Nullify progress bar, not really used *\/ */
/* void nullifyPB() { */
/*   pb = NULL; */
/* } */


