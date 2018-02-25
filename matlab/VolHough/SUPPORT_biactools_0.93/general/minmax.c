static const char rcsid[] = "$Id: minmax.c,v 1.3 2002/10/10 22:40:44 michelich Exp $";
/*
 *
 * MINMAX.C	Return min and max of numeric array.
 *
 * The calling syntax is:
 *
 *		[min max]=MINMAX(A)
 *
 */

#include "mex.h"

#if !defined(max)
#define	max(A, B)	((A) > (B) ? (A) : (B))
#endif

#if !defined(min)
#define	min(A, B)	((A) < (B) ? (A) : (B))
#endif

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[]) {
  /* Declare variables */
  double *a; /* Pointer to input array */
  int empty; /* Is the input empty? */

  /* Check for proper number of arguments */
  
  if (nrhs!=1)
    mexErrMsgTxt("MINMAX requires one input argument.");
  else if (nlhs>2)
    mexErrMsgTxt("Too many output arguments.");
  
  /* Input must be numeric. */
  if (!mxIsNumeric(prhs[0]) || mxIsComplex(prhs[0]) || mxIsSparse(prhs[0])  || !mxIsDouble(prhs[0]))
    mexErrMsgTxt("MINMAX requires that A be an array of noncomplex, nonsparse doubles.");
  
  /* Assign pointer to the input array */
  a=mxGetPr(prhs[0]);

  /* Create a matrix for the return arguments */
  /* If empty input, return empty output */
  empty=mxIsEmpty(prhs[0]);
  if (nlhs==2) {
    plhs[0]=mxCreateDoubleMatrix(empty?0:1,empty?0:1,mxREAL);
    plhs[1]=mxCreateDoubleMatrix(empty?0:1,empty?0:1,mxREAL);
    }
  else {
    plhs[0]=mxCreateDoubleMatrix(empty?0:1,empty?0:2,mxREAL);
    }

  if (!empty) {
    /* Do the actual min/max computation */
    int aLen=mxGetM(prhs[0])*mxGetN(prhs[0]);
    int NaNcnt=0;
    double aMin=mxGetInf();
    double aMax=-mxGetInf();
    int i;
    for (i=0; i<aLen; i++) {
      if (mxIsNaN(a[i])) 
        NaNcnt++;
      else {
        aMin=min(aMin,a[i]);
        aMax=max(aMax,a[i]);
        }
      }

    /* If every element is NaN, return NaN's */
    if (NaNcnt==aLen)
      aMax=aMin=mxGetNaN();

    /* Assign output */
    if (nlhs==2) {
      mxGetPr(plhs[0])[0]=aMin;
      mxGetPr(plhs[1])[0]=aMax;
      }
    else {
      mxGetPr(plhs[0])[0]=aMin;
      mxGetPr(plhs[0])[1]=aMax;
      }
    }
  return;
  }

/* Modification History:
 * 
 * $Log: minmax.c,v $
 * Revision 1.3  2002/10/10 22:40:44  michelich
 * Removed #define NO_BUILT_IN_SUPPORT_FOR_BOOL.
 * MATLAB include file version.h automatically detects this based on the compiler used.
 *
 * Revision 1.2  2002/10/10 19:20:53  michelich
 * Converted from C++ to C
 * Changed name from minmax.cpp to minmax.c
 *
 * Revision 1.1  2002/08/27 22:24:16  michelich
 * Initial CVS Import
 *
 *
 * Pre CVS History Entries:
 * Francis Favorini, 1998/10/13.
 *
 */
