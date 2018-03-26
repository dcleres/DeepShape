static const char rcsid[] = "$Id: scaled2rgb.c,v 1.5 2003/04/18 17:51:47 michelich Exp $";
/*
 * scaled2rgb.c - Convert scaled image to RGB image
 *
 * SCALED2RGB Convert scaled image to RGB image.
 *   SCALED2RGB converts the matrix X and corresponding
 *   colormap CMAP to RGB (truecolor) format using the 
 *   specified clipping limits (CLIM).
 *
 *   RGB = SCALED2RGB(X,CMAP,CLIM)
 *
 *      X is input image to convert (any number of dimensions)
 *      CMAP is the colormap (n x 3)
 *      CLIM is the clipping limits for the scaling (2 element vector)
 *      RGB is an size(X)-by-3 uint8 truecolor array 
 *
 *      CMAP can be:
 *      - A standard MATLAB colormap (doubles with values between 0 and 1)
 *      - A uint8 truecolor colormap generated using uint8(round(CMAP*255))
 *          If the same colormap will be used many times and the image to
 *          convert is small, cacheing the uint8 version of the colormap
 *          will increase performance.
 *
 *   See also IND2RGB, IND2GRAY, RGB2IND (in the Image Processing Toolbox).
 */

/* TODO: Handle NaNs more efficiently */

#include <math.h>
#include "mex.h"

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[]) 
{
  /* Check for proper number of arguments */
  if (nrhs!=3)
    mexErrMsgTxt("SCALED2RGB requires 3 input arguments.");
  else if (nlhs>1)
    mexErrMsgTxt("SCALED2RGB requires 0 or 1 output arguments.");
  
  {
    /* --- Declare & Initialize variables --- */
    int n,cmapIndexInt;        /* Generics counters & colormap index for current input array value (int) */
    double k1,cmapIndexDouble; /* Temporary constant & colormap index for current input array value (double) */
    const int *inDims=mxGetDimensions(prhs[0]);               /* Number of elements in each dimension of input array */
    const int numInDims=mxGetNumberOfDimensions(prhs[0]);     /* Number of dimensions in input array */
    const int numInElements=mxGetNumberOfElements(prhs[0]);   /* Number of elements in input array */
    const int cmapLength=mxGetM(prhs[1]);                     /* Number of entries in colormap */
    const int numCmapElements=mxGetNumberOfElements(prhs[1]); /* Number of elements in colormap array */
    int *outDims=NULL;                                        /* Number of elements in each dimension output array */
    
    unsigned char *cmapPtr_uint8=NULL;      /* Pointer to colormap array (converted to uint8's)  */
    const double *inPtr=mxGetPr(prhs[0]);   /* Pointer to input array */
    const double *cmapPtr=mxGetPr(prhs[1]); /* Pointer to colormap array */
    const double *climPtr=mxGetPr(prhs[2]); /* Pointer to colormap limits vector */
    unsigned char *outPtr=NULL;             /* Pointer to output array */
    
    const int cmapR2=cmapLength;     /* Offset to second column in colormap */
    const int cmapR3=2*cmapLength;   /* Offset to third colomn in colormap */
    const int outR2=numInElements;   /* Offset to 2nd "Color" of output array */
    const int outR3=2*numInElements; /* Offset to 3rd "Color" of output array */
    
    /* --- Check input arguments --- */
    /* First input must be a real, non-sparse, numeric array of doubles */
    if (!mxIsNumeric(prhs[0]) || mxIsComplex(prhs[0]) || mxIsSparse(prhs[0]) || !mxIsDouble(prhs[0]))
      mexErrMsgTxt("SCALED2RGB: srs must be an array of real, non-sparse, doubles!");
    
    /* Second argument must be a n x 3 colormap (values between 0 & 1)
	   In order to index cmapPtr_uint8 properly, (n*3-1) <= INT_MAX
       However, mxGetNumber of elements returns an int, so there cannot be > INT_MAX elements in an array */
    if (mxIsComplex(prhs[1]) || mxIsSparse(prhs[1]) || (!mxIsDouble(prhs[1]) && !mxIsUint8(prhs[1]))
		|| (mxGetN(prhs[1]) != 3) || (mxGetNumberOfDimensions(prhs[1]) != 2))
      mexErrMsgTxt("SCALED2RGB: cmap must be a n x 3 colormap array of real, non-sparse, doubles or uint8s!"); 

    /* Third argument must be a 1 x 2 or 2 x 1 non-sparse real numeric array */
    if (mxIsComplex(prhs[2]) || mxIsSparse(prhs[2]) || !mxIsDouble(prhs[2])
        || (mxGetNumberOfElements(prhs[2]) != 2) || (mxGetNumberOfDimensions(prhs[2]) != 2))
      mexErrMsgTxt("SCALED2RGB: clim must be a two element vector of real, non-sparse, doubles!");

    /* Colormap limits must be ascending */
    if (climPtr[0] >= climPtr[1])
      mexErrMsgTxt("SCALED2RGB: cmaplim(2) must be greater than cmaplim(1)");

	/* --- Colormap can be a double or uint8 matrix --- */
    if (mxIsDouble(prhs[1]))
	{  
      /* Colormap is a double.  Check it and convert it to uint8s */

	  /* Check all of the colormap values are between zero and one */
      for (n=0; n<numCmapElements; n++)
      {	
        if (mxIsNaN(cmapPtr[n]) || (cmapPtr[n]>1.0) || (cmapPtr[n]<0.0))
          mexErrMsgTxt("SCALED2RGB: all colormap entries must be between zero and one!");
      }

      /* --- Calculate colormap --- */
      /* Allocate memory for the colormap */
      cmapPtr_uint8=(unsigned char*)mxCalloc(numCmapElements,sizeof(unsigned char));
      if (cmapPtr_uint8==NULL)
        mexErrMsgTxt("SCALED2RGB: Unable to create array for uint8 colormap.");
    
      /* Convert the colormap to 8-bits per color */
      for (n=0; n<numCmapElements; n++)
      {
        /* uint8(round(cmap*255)) in MATLAB */
        cmapPtr_uint8[n]=(unsigned char)(floor(cmapPtr[n]*255.0+0.5));
      }
    }
	else
	{
       /* Colormap is uint8. Just use it */
       cmapPtr_uint8=(unsigned char *)mxGetData(prhs[1]);
	}
	
    /* --- Allocate output array --- */
    /* Allocate memory for any array to hold number of elements in each dimension of output */
    outDims=(int*)mxCalloc(numInDims+1,sizeof(int));
    if (outDims==NULL)
      mexErrMsgTxt("SCALED2RGB: Unable to create array of output dimensions.");

    /* Initialize output dimensions */
    for (n=0; n<numInDims; n++)
    { 
      outDims[n] = inDims[n];  /* All but final dimension is the same as the input */
    }
    outDims[numInDims]=3;      /* Final dimension is the three colors (red, green, blue) */
    
    /* Create a matrix for the output RGB */
    plhs[0]=mxCreateNumericArray(numInDims+1,outDims,mxUINT8_CLASS,mxREAL);
    if (plhs[0]==NULL)
      mexErrMsgTxt("SCALED2RGB: Could not create output array.");
    outPtr = (unsigned char *)mxGetData(plhs[0]);

    /* --- Calculate output array --- */
    /* Standard MATLAB scaled CDataMapping technique:
       From MATLAB Help (Graphics: Axes Properties: Axes Color Limits - The CLim Property)
       colormap_index = fix((CData-cmin)/(cmax-cmin)*cm_length)+1
       where CLim = [cmin cmax]
       cm_length = length of colormap
      
       This makes size(cm,1)-1 equal sized bins.  The first bin starts on clim(1)
       and the last bin ends on clim(2).  The bins on each end also include all of
       the points out of the clim range).  Any data greater than clim(2) is set
       to clim(2) and any data less than clim(1) is set to clim(1).
    */
    k1 = ((double)(cmapLength))/(climPtr[1]-climPtr[0]);  /* Initialize constant */
    for (n=0; n<numInElements; n++)
    {
      /* Calculate colormap index
         NOTE: Do not add one, because C++ uses 0 based indexing 
	       & MATLAB uses 1 based indexing
         NOTE: Leave as double before boundary checking to avoid 
               problems with casting NaNs, Infs, -Infs to integers */
      cmapIndexDouble = (inPtr[n]-climPtr[0])*k1;
      
      /* Implement MATLAB fix() function
         rounds the elements of X to the nearest integers towards zero.      
         NOTE: floor(0.0) == 0.0 and ceil(0.0) == 0.0 */
      cmapIndexDouble = (cmapIndexDouble >= 0.0) ? floor(cmapIndexDouble) : ceil(cmapIndexDouble);
	    
      /* Clip the cmapIndex to go from 0 to cmapLength -1 */
      if ((cmapIndexDouble < 0.0) || mxIsNaN(cmapIndexDouble))
        /* Clip NaN to zero, since the standard image functions 
		   in MATLAB displays NaNs as the minimum in the colormap
           NOTE: The mxIsNaN slows the function down quite a bit (approximately 10%)
		   Without this, the > cmapLength-1 matches
           TODO: Find a better way to implement this??? */
         cmapIndexInt = 0;                    /* Clip to low value */
       else if (cmapIndexDouble > (float)((cmapLength-1))) 
         cmapIndexInt = cmapLength-1;         /* Clip to high value */
       else
         cmapIndexInt = (int)cmapIndexDouble; /* Cast as integer */
  
      /* Extract the r,g,b components from the colormap */
      outPtr[n]=cmapPtr_uint8[cmapIndexInt];
      outPtr[n+outR2]=cmapPtr_uint8[cmapIndexInt+cmapR2];
      outPtr[n+outR3]=cmapPtr_uint8[cmapIndexInt+cmapR3];
    }
    /* Free dynamically allocated memory 
	   Note: cmapPtr_uint8 is NOT allocated by scaled2rgb
	         if the colormap was passed as UINT8 */
    mxFree(outDims);
	if (mxIsDouble(prhs[1])) mxFree(cmapPtr_uint8);
  }
}

/* Modification History:
 * 
 * $Log: scaled2rgb.c,v $
 * Revision 1.5  2003/04/18 17:51:47  michelich
 * Bug fix: Was not checking bounds of cmap(1)
 *
 * Revision 1.4  2002/09/19 01:05:02  michelich
 * Added ability to pass uint8 colormap for increased performance.
 * Removed redundant error checking
 *
 * Revision 1.3  2002/08/29 22:53:27  crm
 * Fixed incompatible pointer assignment on output array
 *
 * Revision 1.2  2002/08/29 22:10:13  michelich
 * Changed all comments to C style comments for linux compilation
 *
 * Revision 1.1  2002/08/28 19:09:17  michelich
 * Initial CVS Import
 *
 *
 * Pre CVS History Entries:
 * Charles Michelich, 2002/08/26. Added const to rscid to remove potential compiler warning
 *                                Changed to a C file from C++ since no C++ features are being used
 * Charles Michelich, 2002/04/27. First full implementation
 * Charles Michelich, 2002/04/26. continued implemention
 * Charles Michelich, 2002/04/25. original
 *
 */
