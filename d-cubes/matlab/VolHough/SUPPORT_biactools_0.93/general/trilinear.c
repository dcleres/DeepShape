static const char rcsid[] = "$Id: trilinear.c,v 1.5 2003/06/20 20:28:19 michelich Exp $";
/*
 *
 * TRILINEAR.C Trilinear interpolation of 3-D array.
 *
 * The calling syntax is:
 *
 *		VI=TRILINEAR(V,XI,YI,ZI);
 *		VI=TRILINEAR(X,Y,Z,V,XI,YI,ZI);
 *
 */

#include <memory.h>
#include "mex.h"

double *trilinear(int xs,int ys,int zs,double *xo,double *yo,double *zo,double *v,
                  int xis,int yis,int zis,double *xi,double *yi,double *zi,double *vi);

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[]) {
  /* Input args must be numeric vectors or 3-D arrays. */
  int empty=0;                    /* Any args empty? */
  int vArg=nrhs-4;                /* Which of actual args is the V array */
  int isVec[7]={0,0,0,0,0,0,0};   /* Which of all possible args are vectors */
  int numDims[7]={0,0,0,0,0,0,0}; /* Number of dimensions of all possible args */
  int a; /* Loop counter */

  /* Check for proper number of arguments */
  if (nrhs!=4 && nrhs!=7)
    mexErrMsgTxt("TRILINEAR requires 4 or 7 input arguments.");
  else if (nlhs>1)
    mexErrMsgTxt("TRILINEAR requires 0 or 1 output arguments.");
  
  for (a=0; a<nrhs; a++) {
    int idx;
    if (!mxIsNumeric(prhs[a]) || mxIsComplex(prhs[a]) || mxIsSparse(prhs[a])  || !mxIsDouble(prhs[a]))
      mexErrMsgTxt("TRILINEAR requires all arguments to be arrays of noncomplex, nonsparse doubles.");
    idx=7-nrhs+a;                                                    /* Index into isVec/numDims */
    numDims[idx]=mxGetNumberOfDimensions(prhs[a]);
    if (numDims[idx]==2) {                                           /* Might be vector */
      if (mxGetM(prhs[a])==1) {isVec[idx]=2; numDims[idx]=1;}        /* Row vector */
      else if (mxGetN(prhs[a])==1) {isVec[idx]=1; numDims[idx]=1;}   /* Column vector */
      }
    if (a<vArg && numDims[idx]!=1 && numDims[idx]!=3)
      mexErrMsgTxt("TRILINEAR requires X,Y,Z to be vectors or 3-D arrays.");
    else if (a>vArg && numDims[idx]!=1 && numDims[idx]!=2 && numDims[idx]!=3)
      mexErrMsgTxt("TRILINEAR requires XI,YI,ZI to be vectors, or 2-D or 3-D arrays.");
    else if (a==vArg && numDims[idx]!=3)
      mexErrMsgTxt("TRILINEAR requires V to be a 3-D array.");
    if (mxIsEmpty(prhs[a])) {empty=1; break;}
    }

  if (empty) {
    /* If any empty input args, return (3-D) empty output arg */
    const int dims[3]={0,0,0};
    plhs[0]=mxCreateNumericArray(3,dims,mxDOUBLE_CLASS,mxREAL);
    if (plhs[0]==NULL)
      mexErrMsgTxt("Could not create output array.\n");
    }
  else {
    /* Check dimensions of input args X,Y,Z */
    const int *dims=NULL,*vDims=mxGetDimensions(prhs[vArg]);
    int xs=vDims[0];
    int ys=vDims[1];
    int zs=vDims[2];
    int viDims[3]={1,1,1};   /* Dimensions for the output arg VI */
    int xis,yis,zis;
    double *xi,*yi,*zi,*vi,*x,*y,*z,*v,*xo,*yo,*zo,*xiv,*yiv,*ziv;
    int i,j,k,p; /* Loop counters */
    for (a=0; a<vArg; a++) {
      dims=mxGetDimensions(prhs[a]);
      if (numDims[a]==3 && (dims[0]!=xs || dims[1]!=ys || dims[2]!=zs))
        mexErrMsgTxt("If X, Y, or Z is a 3-D array it must be the same size as V.\n");
      else if (numDims[a]==1 && dims[isVec[a]-1]!=vDims[a])
        mexErrMsgTxt("If X, Y, or Z is a vector its size must match to corresponding dimension of V.\n");
      }

    /* Determine dimensions for the output arg VI */
    for (a=0; a<3; a++) {
      dims=mxGetDimensions(prhs[vArg+1+a]);
      if (a<2 || numDims[4+a]!=2)
        viDims[a]=dims[numDims[4+a]==1?isVec[4+a]-1:a];
      }
    xis=viDims[0];
    yis=viDims[1];
    zis=viDims[2];

    /* Create a matrix for the output arg VI */
    plhs[0]=mxCreateNumericArray(3,viDims,mxDOUBLE_CLASS,mxREAL);
    if (plhs[0]==NULL)
      mexErrMsgTxt("Could not create output array.\n");
    vi=mxGetPr(plhs[0]);

    /* Assign pointers to real parts of the input args */
    x=NULL; y=NULL; z=NULL;
    if (vArg>0) {
      x=mxGetPr(prhs[0]);
      y=mxGetPr(prhs[1]);
      z=mxGetPr(prhs[2]);
      }
    v=mxGetPr(prhs[vArg+0]);
    xi=mxGetPr(prhs[vArg+1]);
    yi=mxGetPr(prhs[vArg+2]);
    zi=mxGetPr(prhs[vArg+3]);

    /* Handle original coordinates */
    xo=NULL; yo=NULL; zo=NULL;
    if (vArg==0) {
      /* Create default original coordinates a la ndgrid(1:xs,1:ys,1:zs) (1-based!!) */
      xo=(double*)mxMalloc(xs*ys*zs*sizeof(double));
      yo=(double*)mxMalloc(xs*ys*zs*sizeof(double));
      zo=(double*)mxMalloc(xs*ys*zs*sizeof(double));
      for (k=0,p=0; k<zs; k++)
        for (j=0; j<ys; j++)
          for (i=0; i<xs; i++,p++) {
            xo[p]=i+1;
            yo[p]=j+1;
            zo[p]=k+1;
            }
      }
    else {
      /* User specified original coordinates (expand any vectors into arrays) */
      if (isVec[0]) xo=(double*)mxMalloc(xs*ys*zs*sizeof(double)); else xo=x;
      if (isVec[1]) yo=(double*)mxMalloc(xs*ys*zs*sizeof(double)); else yo=y;
      if (isVec[2]) zo=(double*)mxMalloc(xs*ys*zs*sizeof(double)); else zo=z;
      if (isVec[0] || isVec[1] || isVec[2])
	      for (k=0,p=0; k<zs; k++)
          for (j=0; j<ys; j++)
            for (i=0; i<xs; i++,p++) {
              if (isVec[0]) xo[p]=x[i];
              if (isVec[1]) yo[p]=y[j];
              if (isVec[2]) zo[p]=z[k];
              }
      }

    /* Handle new coordinates (expand any vectors into arrays) */
    xiv=NULL; yiv=NULL; ziv=NULL;
    if (isVec[4]) {xiv=xi; xi=(double*)mxMalloc(xis*yis*zis*sizeof(double));}
    if (isVec[5]) {yiv=yi; yi=(double*)mxMalloc(xis*yis*zis*sizeof(double));}
    if (isVec[6]) {ziv=zi; zi=(double*)mxMalloc(xis*yis*zis*sizeof(double));}
    if (isVec[4] || isVec[5] || isVec[6])
      for (k=0,p=0; k<zis; k++)
        for (j=0; j<yis; j++)
          for (i=0; i<xis; i++,p++) {
            if (isVec[4]) xi[p]=xiv[i];
            if (isVec[5]) yi[p]=yiv[j];
            if (isVec[6]) zi[p]=ziv[k];
          }
    /* Calculate the interpolated values */
    vi=trilinear(xs,ys,zs,xo,yo,zo,v,xis,yis,zis,xi,yi,zi,vi);
    }
  return;
  }

double *trilinear(int xs,int ys,int zs,double *xo,double *yo,double *zo,double *v,
                  int xis,int yis,int zis,double *xi,double *yi,double *zi,double *vi) {

  int xys=xs*ys,xyzs=xs*ys*zs,xyis=xis*yis;     /* Remember sizes to save a few multiplies */
  double *v000=v,  *v010=v+xs,  *v001=v+xys,  *v011=v+xs+xys;      /* Eight points to use for */
  double *v100=v+1,*v110=v+1+xs,*v101=v+1+xys,*v111=v+1+xs+xys;    /* trilinear interpolation */
  double zoLo=*zo,zoHi=*(zo+xyzs-xys);          /* zo bounds */
  double nan=mxGetNaN();
  int c=0;                                      /* Keep track of which zo coord we're on */
  int n,i,j,k;                                  /* Loop counters */
  int a;                                        /* Keep track of which xo coord we're on */
  int b;                                        /* Keep track of which yo coord we're on */
  double xoLo,xoHi;                             /* xo bounds */
  double yoLo,yoHi;                             /* yo bounds */
  double dx;                                    /* Relative distance of xi from xo */
  double dy;                                    /* Relative distance of yi from yo */
  double dz;                                    /* Relative distance of zi from zo */
  double x00,x10,x01,x11,xy0,xy1;

  for (k=0; k<zis; k++) {
    if (*zi<zoLo || *zi>zoHi) {                 /* Is this zi coord is out of bounds? */
      xi+=xyis; yi+=xyis; zi+=xyis;
      for (n=0; n<xyis; n++)
        *vi++=nan;                              /* Fill with NaN's */
      continue;                                 /* Skip to next zi coord */
      }
    while (*zi>=*(zo+xys) && c<zs-2)            /* Find lower bounding zo coord */
      c++,xo+=xys,yo+=xys,zo+=xys,v+=xys,v000+=xys,v010+=xys,v001+=xys,v011+=xys,v100+=xys,v110+=xys,v101+=xys,v111+=xys;
    dz=(*zi-*zo)/(*(zo+xys)-*zo);               /* Relative distance of zi from zo */
    yoLo=*yo; yoHi=*(yo+xys-xs);                /* yo bounds */
    b=0;                                        /* Keep track of which yo coord we're on */
    for (j=0; j<yis; j++) {
      if (*yi<yoLo || *yi>yoHi) {               /* Is this yi coord is out of bounds? */
        xi+=xis; yi+=xis; zi+=xis;
        for (n=0; n<xis; n++)
          *vi++=nan;                            /* Fill with NaN's */
        continue;                               /* Skip to next yi coord */
        }
      while (*yi>=*(yo+xs) && b<ys-2)           /* Find lower bounding yo coord */
        b++,xo+=xs,yo+=xs,zo+=xs,v+=xs,v000+=xs,v010+=xs,v001+=xs,v011+=xs,v100+=xs,v110+=xs,v101+=xs,v111+=xs;
      dy=(*yi-*yo)/(*(yo+xs)-*yo);              /* Relative distance of yi from yo */
      xoLo=*xo; xoHi=*(xo+xs-1);                /* xo bounds */
      a=0;                                      /* Keep track of which xo coord we're on */
      for (i=0; i<xis; i++,xi++,yi++,zi++,vi++) {
        if (*xi<xoLo || *xi>xoHi) {             /* Is this xi coord is out of bounds? */
          *vi=nan;                              /* Fill with NaN */
          continue;                             /* Skip to next xi coord */
          }
        while (*xi>=*(xo+1) && a<xs-2)          /* Find lower bounding xo coord */
          a++,xo++,yo++,zo++,v++,v000++,v010++,v001++,v011++,v100++,v110++,v101++,v111++;
        dx=(*xi-*xo)/(*(xo+1)-*xo);      /* Relative distance of xi from xo */
        x00=*v000+dx*(*v100-*v000);
        x10=*v010+dx*(*v110-*v010);
        x01=*v001+dx*(*v101-*v001);
        x11=*v011+dx*(*v111-*v011);
        xy0=x00+dy*(x10-x00);
        xy1=x01+dy*(x11-x01);
        *vi=xy0+dz*(xy1-xy0);
        }
      /* Reset to beginning of this set of x coords */
      xo-=a,yo-=a,zo-=a,v-=a,v000-=a,v010-=a,v001-=a,v011-=a,v100-=a,v110-=a,v101-=a,v111-=a;
      }
    /* Reset to beginning of this set of y coords */
    b*=xs;
    xo-=b,yo-=b,zo-=b,v-=b,v000-=b,v010-=b,v001-=b,v011-=b,v100-=b,v110-=b,v101-=b,v111-=b;
    }
  return vi;
  }

/* Modification History:
 * 
 * $Log: trilinear.c,v $
 * Revision 1.5  2003/06/20 20:28:19  michelich
 * Don't expand user specified original coordinates when all are matricies.
 * - This bug led to slower execution, not incorrect results (scoping problem).
 * Also changed p=0 location of default original coordinates for code symmetry.
 *
 * Revision 1.4  2003/01/01 00:17:53  michelich
 * Corrected source filename in comments.
 *
 * Revision 1.3  2002/10/10 22:02:00  michelich
 * Converted from C++ to C
 * Changed name from trilinear.cpp to trilinear.c
 *
 * Revision 1.2  2002/08/29 23:05:31  crm
 * Moved declaratino of 'a' outside of for block due to new ISO 'for' scoping
 *
 * Revision 1.1  2002/08/27 22:24:19  michelich
 * Initial CVS Import
 *
 *
 * Pre CVS History Entries:
 * Francis Favorini, 1998/11/10.
 * Francis Favorini, 1998/11/18. Fill out of bounds areas with NaN instead of 0.
 *                               Expand vector args to arrays.
 * Francis Favorini, 1998/12/22. Allow XI,YI,ZI to be 2-D.
 *
 */
