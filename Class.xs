/**
 * Original version is from Check::Unitcheck, by AJGOUGH.
 *
 * When usemultiplicity is not defined, for some reason PL_unitcheckav is not
 * defined - perlapi.h only defines this when MULTIPLICITY is defined, although
 * it still seems to be available I've not yet tracked down exactly what it's
 * defined as.
 */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

int _unitcheckify(SV* sv);
int _add_cv_to_reqd(CV *cv);

/* work out which function to really call, ifdefs probably sensible here */
#if (PERL_VERSION >= 10)
/* We have a UNITCHECK to use, as we're getting called thus:
COMPILATION UNIT:
some code
use Check::UnitCheck sub { ... };
some more code

which is the same as:

COMPILATION UNIT:
some code
BEGIN {require Check::UnitCheck; Check::UnitCheck->import( sub {...})}
some more code

we can be fairly certain that we'll get the correct unitcheckav 
 */
int _add_cv_to_reqd(CV *cv) {
  if (!cv)
    croak("Need a CV");

  CvSPECIAL_on(cv);

  if (!PL_unitcheckav)
    PL_unitcheckav = newAV();
  
  av_unshift(PL_unitcheckav, 1);
  av_store(PL_unitcheckav, 0, (SV*)cv);

  return 0;
}
#else
#error "Need perl5.10+"
#endif

int _unitcheckify(SV *sv) {
  CV *cv;
  cv = (CV*)SvRV(sv);
  SvREFCNT_inc((SV*)cv);
  if (_add_cv_to_reqd(cv)) {
    /* didn't work for a recoverable reason */
    SvREFCNT_dec((SV*)cv);
  }
  else {
    return 0;
  }
}

MODULE = EntityModel::Class		PACKAGE = EntityModel::Class

int
unitcheckify(sv)
    INPUT:
	SV *		sv
    CODE:
        if (!sv) /*SVt_PVCV */
	  croak("Need a subref a");
	if (!SvRV(sv))
	  croak("Need a subref b");
	if (! (SvTYPE(SvRV(sv)) == SVt_PVCV))
	  croak("Need a subref c");

	RETVAL = _unitcheckify(sv);
    OUTPUT:
	RETVAL


