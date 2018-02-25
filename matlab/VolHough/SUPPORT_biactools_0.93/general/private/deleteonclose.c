#if !defined(WINDOWS) && !defined(_WIN32)
??=error "You do not need to compile this on Unix.  This is not the file you are looking for."
#else

#include <windows.h>
#include <stdio.h>
#include <mex.h>

#define FILE_SHARE_DELETE 0x00000004

void
mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
  HANDLE h;
  char * arg1 = NULL;
  enum {
    STATE_ACQUIRE,  /* acquire the handle */
    STATE_RELEASE,  /* release the handle */
    STATE_ATOMIC    /* do both at once */
  } state;
  
  if (nrhs < 1 ||
      nrhs > 2 ||
      (nrhs == 1 && !mxIsChar(prhs[0])) ||
      (nrhs == 2 && !mxIsChar(prhs[1]))) {
    mexPrintf("function has %d args", nlhs);
    mexErrMsgTxt("Usage: deleteonclose('<filename>')\n       deleteonclose('<filename>', ['acquire'|'release'])");
  }

  if ((arg1 = mxArrayToString(prhs[0])) == NULL) {
    mexErrMsgTxt("Error converting arg1 to string!\n");
  }

  if (nrhs == 2) {
    char * statestr = NULL;
    if ((statestr = mxArrayToString(prhs[1])) != NULL) {
      mxFree(arg1);
      mexErrMsgTxt("Error converting arg2 to string!\n");
    }
    if (strcmp(statestr, "acquire") == 0)
      state = STATE_ACQUIRE;
    else if (strcmp(statestr, "release") == 0)
      state = STATE_RELEASE;
    else
      mexErrMsgTxt("arg2 must be one of 'acquire' or 'release'!\n");
    mxFree(statestr);
  } else {
    state = STATE_ATOMIC;
  }

  if (state == STATE_ACQUIRE || state == STATE_ATOMIC) {
    /* acquire a new handle to the file */
    char * filename = arg1;
    h = CreateFile(filename,
		   GENERIC_READ,
		   FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
		   NULL,
		   OPEN_ALWAYS,
		   FILE_ATTRIBUTE_NORMAL | FILE_FLAG_DELETE_ON_CLOSE,
		   NULL);
    if (h == INVALID_HANDLE_VALUE) {
      mexPrintf("Error deleting/opening %s: %d\n", filename, GetLastError());
      mxFree(arg1);
      return;
    }
  } else if (state == STATE_RELEASE) {
    /* get the handle given as an argument */
    unsigned char * handleptr = (unsigned char *)&h;
    char * handlename = arg1;
    unsigned int scanned;
    if (strncmp(handlename, "HANDLE", 6) != 0) {
      mxFree(arg1);
      mexErrMsgTxt("arg1 must be a handle returned by deleteoncloseacq\n");
    }
    handlename += 6;
    while (handleptr - (unsigned char *)&h < sizeof(h) &&
	   sscanf(handlename, "%%%x", &scanned) == 1) {
      *(handleptr++) = (unsigned char)scanned;
    }
  }

  mxFree(arg1);

  /*
   * at this point we have an open handle to the file that is marked for
   * "delete on close"
   */

  if (state == STATE_ACQUIRE) {
    /* convert the open handle into a string to return to Matlab */
    unsigned char * handleptr = (unsigned char *)&h;
    char * handlename = NULL;
    char * handlenameptr = NULL;
    handlename = (char *)malloc(sizeof(h)*3 + 6 + 1);
    handlenameptr = handlename;
    handlenameptr += sprintf(handlenameptr, "HANDLE");
    while (handleptr - (char *)&h < sizeof(h)) {
      handlenameptr += sprintf(handlenameptr, "%%%02x", (unsigned int)*(handleptr++));
    }
    plhs[0] = mxCreateString(handlename);
  } else if (state == STATE_RELEASE || state == STATE_ATOMIC) {
    /* otherwise, we're done */
    CloseHandle(h);
  }
}

#endif /* #ifdef WINDOWS #else */

/*
 * $Log: deleteonclose.c,v $
 * Revision 1.5  2003/01/10 15:24:33  michelich
 * Corrected enum syntax
 *
 * Revision 1.4  2003/01/10 15:14:34  gadde
 * Try this for windows/unix detection.
 *
 * Revision 1.3  2003/01/08 17:27:07  gadde
 * New method for deleteonclose -- still doesn't work on Windows yet :(
 *
 * Revision 1.2  2002/10/08 20:08:42  gadde
 * minor fixes
 *
 */

