static char rcsid[] = "$Id: writexml.c,v 1.25 2003/11/17 21:26:57 gadde Exp $";

/* writexml.cpp --
 *
 * Author: Syam Gadde (gadde@biac.duke.edu) May/June 2002
 *
 * See writexml.m for documentation.
 */

#if defined(WINDOWS) || defined(_WIN32)
#define _REENTRANT
#endif

#include <libxml/tree.h>

#include <time.h>
#include <assert.h>
#include <string.h>

#include "mex.h"
#include "matrix.h"

#define DEBUG 0

static void fillXmlNode(xmlNodePtr np, const mxArray * sm);
static char * getNewStringFromMxArray(const mxArray * mxstr);
static int isValidXmlStruct(const mxArray * sm, const char * path);

static char errmsgbuf[8192];
char * errmsg = &errmsgbuf[0];

enum { OE_PINST, OE_COMMENT, OE_TEXT, OE_ELEMENT };
typedef struct {
    int type;
    double rank;
    mxArray * node;
    char * name;
} orderedentry;

void
mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
    const mxArray * sm = NULL;
    xmlDocPtr doc = NULL;
    xmlNodePtr comment = NULL;
    time_t currtime;
    char * xmlfn = NULL;
    int oldindent;

    if (nrhs != 2)
		mexErrMsgTxt("Incorrect number of input arguments\nUsage: writexml(xmlstruct, xmlfilename)");
    if (nlhs > 1)
        mexErrMsgTxt("Too many output arguments.\n");

    sm = prhs[0];

#if DEBUG
sprintf(errmsg, "Checking validity\n");
mexWarnMsgTxt(errmsg);
#endif
    if (!isValidXmlStruct(sm, "ARG1"))
	return;
    
#if DEBUG
sprintf(errmsg, "Checked validity\n");
mexWarnMsgTxt(errmsg);
#endif
    doc = xmlNewDoc((const xmlChar *)"1.0");

    comment = xmlNewComment((xmlChar *)"");
    xmlNodeAddContent(comment, (xmlChar *)"AUTOGEN:\n File automatically generated by MATLAB MEX-function writexml()\n (");
    xmlNodeAddContent(comment, (xmlChar *)rcsid);
    xmlNodeAddContent(comment, (xmlChar *)")\n on ");
    currtime = time(NULL);
    xmlNodeAddContent(comment, (xmlChar *)ctime(&currtime));
    xmlAddChild((xmlNodePtr)doc, comment);

    fillXmlNode((xmlNodePtr)doc, sm);

    xmlfn = getNewStringFromMxArray(prhs[1]);
    oldindent = xmlIndentTreeOutput;
    xmlIndentTreeOutput = 1;
    if (xmlSaveFormatFile(xmlfn, doc, 1) == -1) {
	sprintf(errmsg, "Error writing XML to file %s\n", xmlfn);
	mexErrMsgTxt(errmsg);
    }
    xmlIndentTreeOutput = oldindent;
    free(xmlfn);

    xmlFreeDoc(doc);
}

static
int
cmpVoidPtr(const void *in1, const void *in2)
{
    void * n1 = *(void **)in1;
    void * n2 = *(void **)in2;
    if (n1 < n2) return -1;
    if (n1 > n2) return 1;
    return 0;
}

static
int
cmpOE(const void *in1, const void *in2)
{
    orderedentry * n1 = *(orderedentry **)in1;
    orderedentry * n2 = *(orderedentry **)in2;
    if (n1->rank < n2->rank) return -1;
    if (n1->rank > n2->rank) return 1;
    return 0;
}

/* complement to qsort, with one extra argument, "elemp", which is a
 * pointer to the value of the element you are searching for in the
 * sorted array pointed to by "base".  Returns index of the first
 * element with the same value, or -1 if not found. */
static
long
binarySearch(void * elemp,
	     void * base, size_t numelems, size_t elemsize,
	     int (*compar)(const void *, const void *))
{
    long lo,hi;
    lo = 0;
    hi = numelems;
    while (lo < hi) {
	long mid = lo + ((hi - lo) / 2);
	int found = 0;
	int cmp;
	while (mid >= 0 &&
	       (cmp = compar(elemp, ((char *)base) + (mid * elemsize))) == 0) {
	    found = 1;
	    mid--;
	}
	if (found)
	    return (mid + 1);
	if (cmp < 0)
	    hi = mid;
	else
	    lo = mid + 1;
    }
    return -1;
}

/* create a new array that will hold an extra element,
 * copy old elements and new element to new array, return new array.
 */
static void **
appendToPointerArray(void ** array, void * newelem, int arraysize)
{
    int i;
    void ** newarray = (void **)malloc(sizeof(void *) * (arraysize + 2));
    for (i = 0; i < arraysize; i++) {
	newarray[i] = array[i];
    }
    newarray[arraysize] = newelem;
    newarray[arraysize + 1] = NULL;
    free(array);
    return newarray;
}


static void
fillXmlNode(xmlNodePtr np, const mxArray * sm)
{
    mxArray ** parsed = NULL;
    size_t numparsed = 0;
    orderedentry ** ordered = NULL;
    size_t numordered = 0;
    int numfields = 0;
    int fieldnum;
    int oenum;
    
    parsed = (mxArray **)malloc(sizeof(mxArray *) * 1);
    numparsed = 0;
    parsed[0] = NULL;

    ordered = (orderedentry **)malloc(sizeof(orderedentry *) * 1);
    numordered = 0;

    numfields = mxGetNumberOfFields(sm);

    /* Structure pointed to by sm represents an XML node.
     * Special fields in the structure are defined below.
     * These rules are strictly enforced by isValidXMLStruct().
     *  NSDEFS: itself a single structure with keys being namespace prefixes
     *          and values being the namespace URLs.
     *  BASE:   string representing base URL for this file (only special
     *          if current node is the root element).
     *  NAMESPACE:  string representing namespace URL for this node
     *  ATTRS:  itself a single structure with keys being names of attributes
     *          for this node and values being a structure with single field
     *          "VALUE" which points to string value for the attribute.
     *  PINSTS:  a cell array of processing instructions.  Each processing
     *          instruction is itself a cell array: the first element
     *          is the string name of the instruction, the second element
     *          is the string content of the instruction, and the third
     *          element (optional) is the rank of this node with respect
     *          to the other children of the current node, in document order.
     *  COMMENTS:  itself a structure array, with field "VALUE" pointing
     *          to the string content of the comment, and optional field
     *          "CHILDRANK" being the rank of this node with respect
     *          to the other children of the current node, in document order.
     *  VALUE:  the string content of this node, as characterized by
     *          the concatenation of all text node children of the
     *          current node.
     *  VALUECHILDRANK:  the rank of the "VALUE" node with respect to the
     *          other children of the current node, in document order.
     *  CHILDRANK:  the rank of the current node with respect to all
     *          the other children of the current node's parent
     *          (i.e. current node's siblings).
     * Any other fields point to a cell array of structures, one structure
     * for each child element with the same name as the field, recursively
     * following the above rules.
     */

    /* first grab namespace definitions and apply them */
    for (fieldnum = 0; fieldnum < numfields; fieldnum++) {
	const char * fieldname = NULL;
	mxArray * fieldval = NULL;
	fieldname = mxGetFieldNameByNumber(sm, fieldnum);
	fieldval = mxGetFieldByNumber(sm, 0, fieldnum);
	if (strcmp(fieldname, "NSDEFS") == 0) {
	    int numdefs = mxGetNumberOfFields(fieldval);
	    int defnum;
	    for (defnum = 0; defnum < numdefs; defnum++) {
		const char * defname = NULL;
#if DEBUG
sprintf(errmsg, "NSDEF %s\n", defname);
mexWarnMsgTxt(errmsg);
#endif
		mxArray * defvaluearray = NULL;
		char * value = NULL;
		defname = mxGetFieldNameByNumber(fieldval, defnum);
		defvaluearray = mxGetFieldByNumber(fieldval, 0, defnum);
		value = getNewStringFromMxArray(defvaluearray);
		if (strcmp(defname, "DEFAULT") == 0) /* default namespace */
		    defname = NULL;
		xmlNewNs(np, (xmlChar *)value, (xmlChar *)defname);
		free(value);
	    }
	}
    }

    /* now do those children that have a rank */
    for (fieldnum = 0; fieldnum < numfields; fieldnum++) {
	const char * fieldname = NULL;
	mxArray * fieldval = NULL;
	fieldname = mxGetFieldNameByNumber(sm, fieldnum);
	fieldval = mxGetFieldByNumber(sm, 0, fieldnum);
#if DEBUG
sprintf(errmsg, "Check ranks of %s\n", fieldname);
mexWarnMsgTxt(errmsg);
#endif
	if (strcmp(fieldname, "NSDEFS") == 0) {
	    continue;
	} else if ((np->doc == NULL || (xmlNodePtr)np->doc == np) &&
		   strcmp(fieldname, "BASE") == 0) {
	    /* do nothing */
	} else if (strcmp(fieldname, "NAMESPACE") == 0) {
	    /* do nothing */
	} else if (strcmp(fieldname, "ATTRS") == 0) {
	    /* do nothing, attributes are unordered */
	} else if (strcmp(fieldname, "VALUE") == 0) {
	    /* do nothing (taken care of by VALUECHILDRANK below) */
	} else if (strcmp(fieldname, "CHILDRANK") == 0) {
	    /* do nothing (taken care of by parent) */
	} else if (strcmp(fieldname, "PINSTS") == 0) {
	    int numinsts = mxGetN(fieldval);
	    int instnum;
	    for (instnum = 0; instnum < numinsts; instnum++) {
		mxArray * pinst = NULL;
		pinst = mxGetCell(fieldval, instnum);
		if (mxGetN(pinst) == 3) {
		    double * rankptr = NULL;
		    orderedentry * newoe = NULL;
		    rankptr = mxGetPr(mxGetCell(pinst, 2));
		    newoe = (orderedentry *)malloc(sizeof(orderedentry));
		    newoe->type = OE_PINST;
		    newoe->rank = *rankptr;
		    newoe->node = pinst;
		    ordered = (orderedentry **)appendToPointerArray((void **)ordered, newoe, numordered++);
		}
	    }
	} else if (strcmp(fieldname, "COMMENTS") == 0) {
	    int valuefn = 0;
	    int childrankfn = 0;
	    int numcomments = 0;
	    int commentnum;
	    valuefn = mxGetFieldNumber(fieldval, "VALUE");
	    childrankfn = mxGetFieldNumber(fieldval, "CHILDRANK");
	    numcomments = mxGetN(fieldval);
	    if (childrankfn != -1) {
		for (commentnum = 0; commentnum < numcomments; commentnum++) {
		    mxArray * commentstr = NULL;
		    double * rankptr = NULL;
		    commentstr = mxGetFieldByNumber(fieldval, commentnum, valuefn);
		    rankptr = mxGetPr(mxGetFieldByNumber(fieldval, commentnum, childrankfn));
		    if (rankptr != NULL) {
			orderedentry * newoe = NULL;
			newoe = (orderedentry *)malloc(sizeof(orderedentry));
			newoe->type = OE_COMMENT;
			newoe->rank = *rankptr;
			newoe->node = commentstr;
			ordered = (orderedentry **)appendToPointerArray((void **)ordered, newoe, numordered++);
		    }
		}
	    }
	} else if (strcmp(fieldname, "VALUECHILDRANK") == 0) {
	    mxArray * valuenode = NULL;
	    valuenode = mxGetField(sm, 0, "VALUE");
	    if (valuenode != NULL) {
		double * rankptr = NULL;
		orderedentry * newoe = NULL;
		rankptr = mxGetPr(fieldval);
		newoe = (orderedentry *)malloc(sizeof(orderedentry));
		newoe->type = OE_TEXT;
		newoe->rank = *rankptr;
		newoe->node = valuenode;
		ordered = (orderedentry **)appendToPointerArray((void **)ordered, newoe, numordered++);
	    }
	} else {
	    /* child node */
	    int numcells = mxGetNumberOfElements(fieldval);
	    int cellnum;
	    for (cellnum = 0; cellnum < numcells; cellnum++) {
		mxArray * cell = NULL;
		mxArray * rankfield = NULL;
		cell = mxGetCell(fieldval, cellnum);
		rankfield = mxGetField(cell, 0, "CHILDRANK");
		if (rankfield != NULL) {
		    double * rankptr = NULL;
		    orderedentry * newoe = NULL;
		    rankptr = mxGetPr(rankfield);
		    newoe = (orderedentry *)malloc(sizeof(orderedentry));
		    newoe->type = OE_ELEMENT;
		    newoe->rank = *rankptr;
		    newoe->node = cell;
		    newoe->name = strdup(fieldname);
		    ordered = (orderedentry **)appendToPointerArray((void **)ordered, newoe, numordered++);
		}
	    }
	}
    }

#if DEBUG
sprintf(errmsg, "sorting ordered\n");
mexWarnMsgTxt(errmsg);
#endif
    qsort(ordered, numordered, sizeof(ordered[0]), cmpOE);
#if DEBUG
sprintf(errmsg, "sorted ordered\n");
mexWarnMsgTxt(errmsg);
#endif

    for (oenum = 0; oenum < numordered; oenum++) {
	mxArray * newparsedentry = NULL;
	orderedentry * oe = NULL;
	oe = ordered[oenum];
#if DEBUG
sprintf(errmsg, "ordered entry type %d\n", oe->type);
mexWarnMsgTxt(errmsg);
#endif
	switch (oe->type) {
	case OE_PINST: {
	    mxArray * pinst = NULL;
	    char * cname = NULL;
	    char * ccont = NULL;
	    xmlNodePtr newpi = NULL;
	    pinst = oe->node;
	    cname = getNewStringFromMxArray(mxGetCell(pinst, 0));
	    ccont = getNewStringFromMxArray(mxGetCell(pinst, 1));
	    newpi = xmlNewPI((xmlChar *)cname, (xmlChar *)ccont);
	    xmlAddChild(np, newpi);
	    free(cname);
	    free(ccont);
	    newparsedentry = mxGetCell(pinst, 0);
	    break;
	}
	case OE_COMMENT: {
	    mxArray * commentstr = NULL;
	    char * content = NULL;
	    xmlNodePtr commentnode = NULL;
	    commentstr = oe->node;
	    content = getNewStringFromMxArray(commentstr);
	    commentnode = xmlNewComment((xmlChar *)content);
	    xmlAddChild(np, commentnode);
	    free(content);
	    newparsedentry = commentstr;
	    break;
	}
	case OE_TEXT: {
	    mxArray * fieldval = NULL;
	    char * value = NULL;
	    fieldval = oe->node;
	    value = getNewStringFromMxArray(fieldval);
	    xmlNodeAddContent(np, (xmlChar *)value);
	    free(value);
	    newparsedentry = fieldval;
	    break;
	}
	case OE_ELEMENT: {
	    mxArray * cell = NULL;
	    xmlNodePtr newnode = NULL;
	    cell = oe->node;
	    newnode = xmlNewChild(np, NULL, (xmlChar *)oe->name, NULL);
	    free(oe->name);
	    fillXmlNode(newnode, cell);
	    newparsedentry = cell;
	    break;
	}
	default:
	    assert(0); /* should never happen */
	}
	free(oe);
	if (newparsedentry)
	    parsed = (mxArray **)appendToPointerArray((void **)parsed, newparsedentry, numparsed++);
    }
    free(ordered);

    qsort(parsed, numparsed, sizeof(parsed[0]), cmpVoidPtr);

    /* now do everything else */
    for (fieldnum = 0; fieldnum < numfields; fieldnum++) {
	const char * fieldname = NULL;
	mxArray * fieldval = NULL;
	fieldname = mxGetFieldNameByNumber(sm, fieldnum);
	fieldval = mxGetFieldByNumber(sm, 0, fieldnum);
#if DEBUG
sprintf(errmsg, "adding %s\n", fieldname);
mexWarnMsgTxt(errmsg);
#endif
	if (strcmp(fieldname, "CHILDRANK") == 0) {
	    /* already took care of this */
	    continue;
	} else if (strcmp(fieldname, "VALUECHILDRANK") == 0) {
	    /* already took care of this */
	    continue;
	} else if (strcmp(fieldname, "NSDEFS") == 0) {
	    /* already took care of this */
	    continue;
	} else if ((np->doc == NULL || (xmlNodePtr)np->doc == np) &&
		   strcmp(fieldname, "BASE") == 0) {
		/* do nothing */
	} else if (strcmp(fieldname, "NAMESPACE") == 0) {
	    char * href = NULL;
	    xmlNsPtr defns = NULL;
	    xmlNsPtr ns = NULL;
	    href = getNewStringFromMxArray (fieldval);
	    defns = xmlSearchNs(np->doc, np, NULL);
	    ns = xmlSearchNsByHref(np->doc, np, (xmlChar *)href);
	    if (defns && strcmp((char *)defns->href, href) == 0)
		xmlSetNs(np, xmlCopyNamespace(defns));
	    else if (ns)
		xmlSetNs(np, xmlCopyNamespace(ns));
	    free(href);
	} else if (strcmp(fieldname, "ATTRS") == 0) {
	    int numattrs = 0;
	    int attrnum;
	    numattrs = mxGetNumberOfFields(fieldval);
	    for (attrnum = 0; attrnum < numattrs; attrnum++) {
		const char * attrname = NULL;
		mxArray * attrfield = NULL;
		mxArray * attrval = NULL;
		char * value = NULL;
		attrname = mxGetFieldNameByNumber(fieldval, attrnum);
		attrfield = mxGetFieldByNumber(fieldval, 0, attrnum);
		if (binarySearch(&attrfield, parsed, numparsed,
				 sizeof(parsed[0]), cmpVoidPtr) != -1)
		    continue;
		attrval = mxGetField(attrfield, 0, "VALUE");
		value = getNewStringFromMxArray(attrval);
		xmlNewProp(np, (xmlChar *)attrname, (xmlChar *)value);
		free(value);
	    }
	} else if (strcmp(fieldname, "PINSTS") == 0) {
	    int numinsts = 0;
	    int instnum;
	    numinsts = mxGetN(fieldval);
	    for (instnum = 0; instnum < numinsts; instnum++) {
		mxArray * pinst = NULL;
		mxArray * aname = NULL;
		mxArray * acont = NULL;
		char * cname = NULL;
		char * ccont = NULL;
		xmlNodePtr newpi = NULL;
		pinst = mxGetCell(fieldval, instnum);
		aname = mxGetCell(pinst, 0);
		acont = mxGetCell(pinst, 1);
		cname = getNewStringFromMxArray(aname);
		ccont = getNewStringFromMxArray(acont);
		if (binarySearch(&aname, parsed, numparsed,
				 sizeof(parsed[0]), cmpVoidPtr) != -1)
		    continue;
		newpi = xmlNewPI((xmlChar *)cname, (xmlChar *)ccont);
		xmlAddChild(np, newpi);
		free(cname);
		free(ccont);
	    }
	} else if (strcmp(fieldname, "COMMENTS") == 0) {
	    int numcomments = 0;
	    int commentnum;
	    numcomments = mxGetN(fieldval);
	    for (commentnum = 0; commentnum < numcomments; commentnum++) {
		mxArray * commentstr = NULL;
		char * content = NULL;
		xmlNodePtr commentnode = NULL;
		commentstr = mxGetField(fieldval, commentnum, "VALUE");
		if (binarySearch(&commentstr, parsed, numparsed,
				 sizeof(parsed[0]), cmpVoidPtr) != -1)
		    continue;
		content = getNewStringFromMxArray(commentstr);
		commentnode = xmlNewComment((xmlChar *)content);
		xmlAddChild(np, commentnode);
		free(content);
	    }
	} else if (strcmp(fieldname, "VALUE") == 0) {
	    char * value = NULL;
	    if (binarySearch(&fieldval, parsed, numparsed,
			     sizeof(parsed[0]), cmpVoidPtr) != -1)
		continue;
	    value = getNewStringFromMxArray(fieldval);
	    xmlNodeAddContent(np, (xmlChar *)value);
	    free(value);
	} else {
	    /* child node */
	    int numcells = 0;
	    int cellnum;
	    numcells = mxGetNumberOfElements(fieldval);
	    for (cellnum = 0; cellnum < numcells; cellnum++) {
		mxArray * cell = NULL;
		xmlNodePtr newnode = NULL;
		cell = mxGetCell(fieldval, cellnum);
		if (binarySearch(&cell, parsed, numparsed,
				 sizeof(parsed[0]), cmpVoidPtr) != -1)
		    continue;
		newnode = xmlNewChild(np, NULL, (xmlChar *)fieldname, NULL);
		fillXmlNode(newnode, cell);
	    }
	}
    }

    free(parsed);
}

static char *
getNewStringFromMxArray(const mxArray * mxval)
{
    if (mxIsDouble(mxval)) {
	int numelems = 0;
	int elemnum;
	int len = 0;
	char ** bufs = NULL;
	double * pr = NULL;
	char * retstr = NULL;
	char * tmpstr = NULL;
	numelems = mxGetNumberOfElements(mxval);
	bufs = (char **)malloc(sizeof(char *) * numelems);
	pr = mxGetPr(mxval);
	for (elemnum = 0; elemnum < numelems; elemnum++) {
	    double val = pr[elemnum];
	    bufs[elemnum] = (char *)malloc(sizeof(char)*120);
	    sprintf(bufs[elemnum], "%.15g", val);
	    len += strlen(bufs[elemnum]) + 1;
	}
	retstr = (char *)malloc(sizeof(char)*len);
	retstr[0] = '\0';
	tmpstr = retstr;
	for (elemnum = 0; elemnum < numelems; elemnum++) {
	    int tmplen = 0;
	    tmplen = strlen(bufs[elemnum]);
	    strncpy(tmpstr, bufs[elemnum], tmplen);
	    free(bufs[elemnum]);
	    tmpstr += tmplen;
	    if (elemnum + 1 < numelems) {
		tmpstr[0] = ' ';
		tmpstr++;
	    } else {
		tmpstr[0] = '\0';
	    }
	}
	free(bufs);
	return retstr;
    } else if (mxIsChar(mxval)) {
	char * buf = NULL;
	int buflen = 0;
	buflen = mxGetM(mxval) * mxGetN(mxval) * sizeof(mxChar) + 1;
	buf = (char *)malloc(sizeof(char)*buflen);
	mxGetString(mxval, buf, buflen);
	return buf;
    } else {
	mexErrMsgTxt("VALUE not double or string!\n");
    }
    return NULL;
}

static
int
isValidXmlStruct(const mxArray * sm, const char * path)
{
    mxArray * attrs = NULL;
    mxArray * pinsts = NULL;
    mxArray * comments = NULL;
    mxArray * value = NULL;
    mxArray * ns = NULL;
    mxArray * vcr = NULL;
    mxArray * cr = NULL;
    mxArray * base = NULL;
    mxArray * defs = NULL;
    int numfields = 0;
    int fieldnum;

#define FUNC "validateXmlStruct: "
#if DEBUG
sprintf(errmsg, FUNC " %s\n", path);
mexWarnMsgTxt(errmsg);
#endif
    if (!mxIsStruct(sm) ||
	mxGetNumberOfElements(sm) != 1) {
	sprintf(errmsg, FUNC "%s must be a (single) struct!\n", path);
	mexWarnMsgTxt(errmsg);
	return 0;
    }

    attrs = mxGetField(sm, 0, "ATTRS");
    pinsts = mxGetField(sm, 0, "PINSTS");
    comments = mxGetField(sm, 0, "COMMENTS");
    value = mxGetField(sm, 0, "VALUE");
    ns = mxGetField(sm, 0, "NAMESPACE");
    vcr = mxGetField(sm, 0, "VALUECHILDRANK");
    cr = mxGetField(sm, 0, "CHILDRANK");
    base = mxGetField(sm, 0, "BASE");
    defs = mxGetField(sm, 0, "NSDEFS");

    if (attrs) {
	int numattrs = 0;
	int attrnum;
	if (!mxIsStruct(attrs) ||
	    mxGetNumberOfElements(attrs) != 1) {
	    sprintf(errmsg, FUNC "%s.ATTRS must be a (single) struct!\n", path);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
	numattrs = mxGetNumberOfFields(attrs);
	for (attrnum = 0; attrnum < numattrs; attrnum++) {
	    const char * attrname = NULL;
	    mxArray * attr = NULL;
	    mxArray * attrval = NULL;
	    attrname = mxGetFieldNameByNumber(attrs, attrnum);
	    attr = mxGetFieldByNumber(attrs, 0, attrnum);
	    if (!mxIsStruct(attr) ||
		mxGetNumberOfFields(attr) != 1 ||
		(attrval = mxGetField(attr, 0, "VALUE")) == NULL ||
		!(mxIsChar(attrval) || mxIsDouble(attrval))) {
		sprintf(errmsg, FUNC "%s.ATTRS.%s must be a single struct with one field named 'VALUE', pointing to a string or double!\n", path, attrname);
		mexWarnMsgTxt(errmsg);
		return 0;
	    }
	}
    }
    if (pinsts) {
	int numpinsts = 0;
	int pinstnum;
	if (!mxIsCell(pinsts)) {
	    sprintf(errmsg, FUNC "%s.PINSTS must be a cell array!\n", path);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
	numpinsts = mxGetNumberOfElements(pinsts);
	for (pinstnum = 0; pinstnum < numpinsts; pinstnum++) {
	    mxArray * pinst = NULL;
	    pinst = mxGetCell(pinsts, pinstnum);
	    if (!mxIsCell(pinst) ||
		mxGetNumberOfElements(pinst) < 2 ||
		mxGetNumberOfElements(pinst) > 3) {
		sprintf(errmsg, FUNC "%s.PINSTS{%d} must be a (1x2) or (1x3) cell array!\n", path, pinstnum);
		mexWarnMsgTxt(errmsg);
		return 0;
	    }
	    if (!mxIsChar(mxGetCell(pinst, 0))) {
		sprintf(errmsg, FUNC "%s.PINSTS{%d}{1} must be a string!\n", path, pinstnum+1);
		mexWarnMsgTxt(errmsg);
		return 0;
	    }
	    if (!mxIsChar(mxGetCell(pinst, 1))) {
		sprintf(errmsg, FUNC "%s.PINSTS{%d}{2} must be a string!\n", path, pinstnum+1);
		mexWarnMsgTxt(errmsg);
		return 0;
	    }
	}
    }
    if (comments) {
	int valuefn = 0;
	int childrankfn = 0;
	int numcomments = 0;
	int commentnum;
	if (!mxIsStruct(comments)) {
	    sprintf(errmsg, FUNC "%s.COMMENTS must be a structure!\n", path);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
	valuefn = mxGetFieldNumber(comments, "VALUE");
	if (valuefn == -1) {
	    sprintf(errmsg, FUNC "%s.COMMENTS structure must have a field VALUE!\n", path);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
	childrankfn = mxGetFieldNumber(comments, "CHILDRANK");
	numcomments = mxGetNumberOfElements(comments);
	commentnum;
	for (commentnum = 0; commentnum < numcomments; commentnum++) {
	    mxArray * comment = NULL;
	    comment = mxGetFieldByNumber(comments, commentnum, valuefn);
	    if (!mxIsChar(comment)) {
		sprintf(errmsg, FUNC "%s.COMMENTS(%d).VALUE must be a string!\n", path, commentnum+1);
		mexWarnMsgTxt(errmsg);
		return 0;
	    }
	    if (childrankfn != -1) {
		mxArray * rankarray = NULL;
		rankarray = mxGetFieldByNumber(comments, commentnum, childrankfn);
		if (!mxIsDouble(rankarray) || mxGetNumberOfElements(rankarray) != 1) {
		    sprintf(errmsg, FUNC "%s.COMMENTS(%d).CHILDRANK must be a scalar double\n", path, commentnum+1);
		    mexWarnMsgTxt(errmsg);
		    return 0;
		}
	    }
	}
    }
    if (value) {
	if (!(mxIsChar(value) || mxIsDouble(value))) {
	    sprintf(errmsg, FUNC "%s.VALUE must be a string or double!\n", path);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
    }
    if (ns) {
	if (!mxIsChar(ns)) {
	    sprintf(errmsg, FUNC "%s.NAMESPACE must be a string!\n", path);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
    }
    if (vcr) {
	if (!mxIsDouble(vcr) || mxGetM(vcr) != 1 || mxGetN(vcr) != 1) {
	    sprintf(errmsg, FUNC "%s.VALUECHILDRANK must be a scalar double!\n", path);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
    }
    if (cr) {
	if (!mxIsDouble(cr) || mxGetM(cr) != 1 || mxGetN(cr) != 1) {
	    sprintf(errmsg, FUNC "%s.CHILDRANK must be a scalar double!\n", path);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
    }
    if (strchr(path, '.') == NULL && ns) {
	if (!mxIsChar(base)) {
	    sprintf(errmsg, FUNC "%s.BASE must be a string!\n", path);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
    }
    if (defs) {
	int numdefs = 0;
	int defnum;
	if (!mxIsStruct(defs) ||
	    mxGetNumberOfElements(defs) != 1) {
	    sprintf(errmsg, FUNC "%s.NSDEFS must be a (single) struct!\n", path);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
	numdefs = mxGetNumberOfFields(defs);
	for (defnum = 0; defnum < numdefs; defnum++) {
	    const char * defname = NULL;
	    mxArray * defval = NULL;
	    defname = mxGetFieldNameByNumber(defs, defnum);
	    defval = mxGetFieldByNumber(defs, 0, defnum);
	    if (!mxIsChar(defval)) {
		sprintf(errmsg, FUNC "%s.NSDEFS.%s must be a string!\n", path, defname);
		mexWarnMsgTxt(errmsg);
		return 0;
	    }
	}
    }

    numfields = mxGetNumberOfFields(sm);
    for (fieldnum = 0; fieldnum < numfields; fieldnum++) {
	const char * fieldname = NULL;
	mxArray * fieldval = NULL;
	int numcells = 0;
	int cellnum;

	fieldname = mxGetFieldNameByNumber(sm, fieldnum);
	if (strcmp(fieldname, "ATTRS") == 0 ||
	    strcmp(fieldname, "NAMESPACE") == 0 ||
	    strcmp(fieldname, "NSDEFS") == 0 ||
	    strcmp(fieldname, "PINSTS") == 0 ||
	    strcmp(fieldname, "COMMENTS") == 0 ||
	    strcmp(fieldname, "VALUE") == 0 ||
	    strcmp(fieldname, "VALUECHILDRANK") == 0 ||
	    strcmp(fieldname, "CHILDRANK") == 0 ||
	    (strcmp(fieldname, "BASE") == 0 && strchr(path, '.') == NULL))
	    continue;

	fieldval = mxGetFieldByNumber(sm, 0, fieldnum);
	if (!mxIsCell(fieldval)) {
	    sprintf(errmsg, FUNC "%s.%s must be a cell array!\n",
		    path, fieldname);
	    mexWarnMsgTxt(errmsg);
	    return 0;
	}
	numcells = mxGetNumberOfElements(fieldval);
	for (cellnum = 0; cellnum < numcells; cellnum++) {
	    mxArray * cell = NULL;
	    int newpathlen = 0;
	    char * newpath = NULL;
	    int retval;
	    cell = mxGetCell(fieldval, cellnum);
	    newpathlen = strlen(path) + strlen(fieldname) + 32;
	    newpath = (char *)malloc(sizeof(char) * newpathlen);
	    strcpy(newpath, path);
	    sprintf(newpath + strlen(path), ".%s{%d}", fieldname, cellnum+1);
	    retval = isValidXmlStruct(cell, newpath);
	    free(newpath);
	    if (!retval)
		return 0;
	}
    }

    return 1;
}

/*
 * $Log: writexml.c,v $
 * Revision 1.25  2003/11/17 21:26:57  gadde
 * Add revision to comment.
 *
 * Revision 1.24  2003/07/22 22:39:36  michelich
 * Syam's fix to support libxml2 versions 2.5.7 & 2.5.8 on Windows.
 *
 * Revision 1.23  2003/07/08 17:47:07  gadde
 * Error message if saving file fails.
 *
 * Revision 1.22  2003/06/26 19:56:46  gadde
 * Get rid of C++-isms
 *
 * Revision 1.21  2003/05/28 12:51:51  gadde
 * Added missing return to quiet compiler warnings.
 *
 * Revision 1.20  2003/05/16 13:55:25  gadde
 * Increase precision of output doubles.
 *
 * Revision 1.19  2003/04/18 16:34:31  gadde
 * New COMMENT structure.
 *
 * Revision 1.18  2003/04/16 15:07:58  gadde
 * Use new "CHILDRANK" field to do what "ORDER" did before.
 * Now XML structures are much more robust when modified
 * (e.g. adding/deleting elements).
 *
 * Revision 1.17  2003/03/28 18:02:44  gadde
 * Fix duplication of comments that exist in ORDER field.
 *
 * Revision 1.16  2003/01/14 17:06:43  gadde
 * Add support for comments.
 *
 * Revision 1.15  2003/01/13 22:02:04  gadde
 * Don't validate BASE field at top level.
 *
 * Revision 1.14  2002/12/11 16:33:06  gadde
 * default namespace changes
 *
 * Revision 1.13  2002/09/30 21:39:49  gadde
 * Don't write the top-level "BASE" element, if it exists.
 *
 * Revision 1.12  2002/09/23 19:25:05  gadde
 * Moved parsing of namespace definitions (NSDEFS) to before ORDER.
 * Will prefer using the default namespace prefix (i.e. none) when
 * writing an XML tag, if the default namespace matches the namespace
 * of the tag.
 *
 * Revision 1.11  2002/09/23 14:04:37  gadde
 * Explicit precision in sprintf removed.
 *
 * Revision 1.10  2002/09/23 13:49:32  gadde
 * Added namespace support.
 *
 * Revision 1.9  2002/07/18 15:34:38  gadde
 * binary search now returns "leftmost" element that matches if there
 * are multiple matches
 *
 * Revision 1.8  2002/06/19 18:26:38  michelich
 * Forgot to remove "return Usage()" in last revision.
 *
 * Revision 1.7  2002/06/19 18:12:10  michelich
 * Use mexErrMsgTxt() instead of return Usage() function on argument check.
 * Removed Usage() function.
 * Removed #include <sys/time.h> for Window compliation
 *
 * Revision 1.5  2002/06/18 19:55:49  gadde
 * Moved documentation to writexml.m
 *
 * Revision 1.3  2002/06/14 21:27:08  gadde
 * Added ORDER information so elements in xml files can be written in
 * the same order in which they were read.  Plus XML struct validation.
 *
 * Revision 1.2  2002/06/12 19:07:16  gadde
 * Removed unnecessary code and added support for XML Processing Instructions.
 *
 * Revision 1.1  2002/06/12 14:06:13  gadde
 * *** empty log message ***
 *
 */
