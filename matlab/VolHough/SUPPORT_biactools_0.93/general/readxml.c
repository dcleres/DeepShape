static char rcsid[] = "$Id: readxml.c,v 1.37 2004/05/06 21:14:09 gadde Exp $";

/* readxml.c --
 *
 * Author: Syam Gadde (gadde@biac.duke.edu) May/June 2002
 *
 * See readxml.m for documentation.
 *
 * readxml requires the libxml2 library and includes
 *  (The Windows libxml2 implemenation requires the iconv library also)
 *
 * Windows build instructions:
   mex -I\\broca\source\external\win32\iconv-1.8.win32\include ...
       -I\\broca\source\external\win32\libxml2-2.4.24.win32\include ...
       readxml.c ...
       \\broca\source\external\win32\libxml2-2.4.24.win32\lib\libxml2.lib
 *
 */

#include <libxml/tree.h>
#include <libxml/xpath.h>

#include <string.h>

#include "mex.h"
#include "matrix.h"

#define DEBUG 0

static char errmsgbuf[8192];
char * errmsg = &errmsgbuf[0];

static mxArray * getTextValue(mxArray * sm, xmlNodePtr np, xmlNodePtr * stringnodes, unsigned long numstringnodes);
static void addAttributes(mxArray * sm, xmlNodePtr np, xmlNodePtr * stringnodes, unsigned long numstringnodes);
static void addNamespaces(mxArray * sm, xmlNodePtr np, xmlNodePtr * stringnodes, unsigned long numstringnodes);
static double addChildren(mxArray * sm, xmlNodePtr np, xmlNodePtr * stringnodes, unsigned long numstringnodes, double rank);
static mxArray * xmlNodeToMxArray(xmlNodePtr np, xmlNodePtr * stringnodes, unsigned long numstringnodes);

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

void
mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
    int buflen;
    char * filename = NULL;
    xmlDocPtr doc = NULL;
    xmlXPathContextPtr ctxt;
    unsigned long numstringnodes;
    xmlNodePtr * stringnodes;
    xmlNodePtr root = NULL;
    int fieldnum;

    if (nrhs < 1)
	mexErrMsgTxt("Not enough input arguments.\nUsage: readxml(xmlfilename[,nsdeclstruct][, stringpaths...])");
    if (nlhs > 1)
        mexErrMsgTxt("Too many output arguments.");
    
    buflen = mxGetM(prhs[0]) * mxGetN(prhs[0]) * sizeof(mxChar) + 1;
    filename = (char *)malloc(sizeof(char)*buflen);
    mxGetString(prhs[0], filename, buflen);
    nrhs--; prhs++;
    doc = xmlParseFile(filename);
    if (doc == NULL)
	mexErrMsgTxt("Parsing file failed.");

    /* create XPath context */
    ctxt = xmlXPathNewContext(doc);
    ctxt->nsNr = 0;
    ctxt->namespaces = NULL;

    /* check if caller provided namespaces */
    if (nrhs > 0 & mxIsStruct(prhs[0])) {
	int numfields = 0;
	int fieldnum = 0;
	numfields = mxGetNumberOfFields(prhs[0]);
	for (fieldnum = 0; fieldnum < numfields; fieldnum++) {
	    const char * prefix = NULL;
	    mxArray * uriarray = NULL;
	    char * uri = NULL;
	    int urilen = 0;
	    xmlNsPtr newns = NULL;
	    prefix = mxGetFieldNameByNumber(prhs[0], fieldnum);
	    uriarray = mxGetFieldByNumber(prhs[0], 0, fieldnum);
	    urilen = mxGetM(uriarray) * mxGetN(uriarray) * sizeof(mxChar);
	    uri = (char *)malloc(sizeof(char) * (urilen + 1));
	    if (!mxIsChar(uriarray) ||
		mxGetString(uriarray, uri, urilen + 1) != 0) {
		xmlFreeDoc(doc);
		free(uri);
		sprintf(errmsg, "Error getting string value of field '%s' in nsdecl struct.\n", prefix);
		mexErrMsgTxt(errmsg);
	    }
	    ctxt->namespaces = (xmlNsPtr *)realloc(ctxt->namespaces, sizeof(xmlNsPtr) * (ctxt->nsNr + 2));
	    newns = (xmlNs *)malloc(sizeof(xmlNs));
	    ctxt->namespaces[ctxt->nsNr] = newns;
	    ctxt->namespaces[ctxt->nsNr+1] = NULL;
	    memset(newns, '\0', sizeof(*newns));
	    newns->type = XML_NAMESPACE_DECL;
	    newns->href = (const xmlChar *)strdup(uri);
	    newns->prefix = (const xmlChar *)strdup(prefix);
	    if (ctxt->nsNr > 0) {
		ctxt->namespaces[ctxt->nsNr-1]->next = newns;
	    }
	    ctxt->nsNr++;
	}
	nrhs--; prhs++;
    }

    /* get list of string nodes from given xpaths */
    root = xmlDocGetRootElement(doc);
    if (root == NULL)
	mexErrMsgTxt("Getting root element failed.");
    numstringnodes = 0;
    stringnodes = (xmlNodePtr *)malloc(sizeof(xmlNodePtr)*1);
    stringnodes[0] = NULL;
    while (nrhs > 0) {
	int xplen;
	char * xp = NULL;
	xmlXPathObjectPtr obj = NULL;
	xmlNodeSetPtr nodeset = NULL;
	xmlNodePtr * newstringnodes = NULL;
	unsigned long i;

	if (!mxIsChar(prhs[0])) {
	    xmlXPathFreeContext(ctxt);
	    xmlFreeDoc(doc);
	    free(stringnodes);
	    printf("Type of argument is %s\n", mxGetClassName(prhs[0]));
	    mexErrMsgTxt("Expected string argument.\n");
	}
	xplen = mxGetM(prhs[0]) * mxGetN(prhs[0]) * sizeof(mxChar);
	xp = (char *)malloc(sizeof(char) * (xplen + 1));
	if (mxGetString(prhs[0], xp, xplen + 1) != 0) {
	    xmlXPathFreeContext(ctxt);
	    xmlFreeDoc(doc);
	    free(stringnodes);
	    free(xp);
	    mexErrMsgTxt("Error in getting string argument.\n");
	}
	nrhs--; prhs++;
	obj = xmlXPathEval((xmlChar *)xp, ctxt);

	if (obj == NULL) {
/* 	    printf("Invalid XPath '%s'?\n", xp); */
	    free(xp);
	    continue;
	}
	if (obj->type != XPATH_NODESET || obj->nodesetval == NULL) {
/* 	    printf("XPath '%s' didn't match any nodes\n", xp); */
	    xmlXPathFreeObject(obj);
	    free(xp);
	    continue;
	}
	free(xp);

	nodeset = obj->nodesetval;
	newstringnodes = (xmlNodePtr *)malloc(sizeof(xmlNodePtr) * (numstringnodes + nodeset->nodeNr + 1));
#if DEBUG
	printf("Adding %d string nodes\n", nodeset->nodeNr);
#endif
	for (i = 0; i < numstringnodes; i++) {
	    newstringnodes[i] = stringnodes[i];
	}
	for (i = 0; i < nodeset->nodeNr; i++) {
	    newstringnodes[i + numstringnodes] = nodeset->nodeTab[i];
	}
	newstringnodes[numstringnodes + nodeset->nodeNr] = NULL;
	free(stringnodes);
	stringnodes = newstringnodes;
	numstringnodes = numstringnodes + nodeset->nodeNr;

	xmlXPathFreeObject(obj);
    }

    {
	unsigned long i;
	unsigned long pos = 0;
	/* sort and get rid of duplicates -- ending NULL moves too */
	qsort(stringnodes, numstringnodes, sizeof(stringnodes[0]), cmpVoidPtr);
	for (i = 0; i < numstringnodes + 1; i++) {
	    if (stringnodes[pos] != stringnodes[i]) {
		pos++;
		if (pos != i)
		    stringnodes[pos] = stringnodes[i];
	    }
	}
    }

    plhs[0] = xmlNodeToMxArray((xmlNodePtr)doc, stringnodes, numstringnodes);

    fieldnum = mxGetFieldNumber(plhs[0], "BASE");
    if (fieldnum != -1) {
	mexErrMsgTxt("Invalid tag BASE in xml file!\n");
    }
    fieldnum = mxAddField(plhs[0], "BASE");
    mxSetFieldByNumber(plhs[0], 0, fieldnum, mxCreateString(filename));

    free(stringnodes);
    free(filename);
    xmlXPathFreeContext(ctxt);
    xmlFreeDoc(doc);
}


static void
addNewCellToField(mxArray * sm, char * fieldname, mxArray * cell)
{
    unsigned int fieldnum;
    mxArray * array = NULL;
    int numcells;
    fieldnum = mxGetFieldNumber(sm, fieldname);
    if (fieldnum == -1)
	fieldnum = mxAddField(sm, fieldname);
    array = mxGetFieldByNumber(sm, 0, fieldnum);
    if (array == NULL) {
	numcells = 0;
	array = mxCreateCellMatrix(1, 1);
	mxSetFieldByNumber(sm, 0, fieldnum, array);
    } else {
        void * data = NULL;
	numcells = mxGetN(array);
	data = mxGetData(array);
	data = mxRealloc(data, (numcells+1)*mxGetElementSize(array));
	if (!data)
	    mexErrMsgTxt("realloc failed!\n");
	mxSetData(array, data);
    }
    mxSetCell(array, numcells, cell);
    mxSetN(array, numcells + 1);
}


static mxArray *
xmlNodeToMxArray(xmlNodePtr np, xmlNodePtr * stringnodes, unsigned long numstringnodes)
{
    const char * names[] = { "" };
    mxArray * sm = NULL;
    mxArray * mval = NULL;
    xmlNodePtr nontextchild = NULL;
    double rank = 0;

#if DEBUG
    if (np->name)
	printf("Parsing %s\n", (char *)np->name);
#endif

    if (np->type != XML_ELEMENT_NODE &&
	np->type != XML_ATTRIBUTE_NODE &&
	np->type != XML_TEXT_NODE &&
	np->type != XML_PI_NODE &&
	np->type != XML_CDATA_SECTION_NODE &&
	np->type != XML_DOCUMENT_NODE)
	return NULL;

    /* create the structure for this element */
    sm = mxCreateStructMatrix(1, 1, 0, names);

    /* do children */
    rank = addChildren(sm, np, stringnodes, numstringnodes, rank);

    /* do namespaces */
    if (np->type != XML_DOCUMENT_NODE)
	addNamespaces(sm, np, stringnodes, numstringnodes);

    /* do attributes */
    if (np->type == XML_ELEMENT_NODE && np->properties)
	addAttributes(sm, np, stringnodes, numstringnodes);

    /* get "value" of element by concatenating all text children */
    mval = getTextValue(sm, np, stringnodes, numstringnodes);
    nontextchild = np->children;
    while (nontextchild &&
	   (nontextchild->type == XML_TEXT_NODE ||
	    nontextchild->type == XML_CDATA_SECTION_NODE)) {
	nontextchild = nontextchild->next;
    }
    if (mval != NULL) {
	int fieldnum = mxGetFieldNumber(sm, "VALUE");
	if (fieldnum != -1) {
	    printf("Invalid tag VALUE in xml file!\n");
	    mxDestroyArray(mval);
	} else {
	    fieldnum = mxAddField(sm, "VALUE");
	    mxSetFieldByNumber(sm, 0, fieldnum, mval);
	}
	if (np->type == XML_ELEMENT_NODE) {
	    fieldnum = mxGetFieldNumber(sm, "VALUECHILDRANK");
	    if (fieldnum != -1) {
		printf("Invalid tag VALUECHILDRANK in xml file!\n");
		mxDestroyArray(mval);
	    } else {
		mxArray * rankptr = mxCreateScalarDouble(++rank);
		fieldnum = mxAddField(sm, "VALUECHILDRANK");
		mxSetFieldByNumber(sm, 0, fieldnum, rankptr);
	    }
	}
    }
    
    return sm;
}

static mxArray *
getTextValue(mxArray * sm, xmlNodePtr np, xmlNodePtr * stringnodes, unsigned long numstringnodes)
{
    unsigned int nonnum = 0;
    const char * space = NULL;
    unsigned int contentlen = 0;
    char * content = NULL;
    int endspace = -1;
    xmlNodePtr cur = NULL;
    mxArray * mval = NULL;

    /* find out if this node should not be parsed as a number */
    if (numstringnodes > 0) {
	/* binary search through sorted list of string nodes */
	unsigned long lo,hi;
	lo = 0;
	hi = numstringnodes;
	while (lo < hi) {
	    unsigned long mid = lo + ((hi - lo) / 2);
	    if (np == stringnodes[mid]) {
		nonnum = 1;
		break;
	    }
	    if (np < stringnodes[mid])
		hi = mid;
	    else
		lo = mid + 1;
	}
    }

    space = " \r\t\n\f\v";
    contentlen = 0;
    content = (char *)malloc(sizeof(char) * (contentlen + 1));
    endspace = -1;
    content[0] = '\0';
#if DEBUG
    printf("getting value of 0x%x, children 0x%x\n", np, np->children);
#endif
    cur = NULL;
    for (cur = np->children; cur != NULL; cur = cur->next) {
	char * validcontent = NULL;
	unsigned int tmplen;
	char * newbuf = NULL;
#if DEBUG
	printf("text?\n");
#endif
	if (cur->type != XML_TEXT_NODE && cur->type != XML_CDATA_SECTION_NODE)
	    continue;
	/* ignore initial space in text nodes */
	if (cur->type == XML_TEXT_NODE && content[0] == '\0')
	    validcontent = (char *)cur->content + strspn((char *)cur->content, space);
	else
	    validcontent = (char *)cur->content;

	tmplen = strlen((char *)validcontent);
	/* find out ending space in case this is the last text node */
	endspace = -1;
	if (cur->type == XML_TEXT_NODE) {
	    for (endspace = tmplen; endspace > 0; endspace--) {
		if (!strchr(space, validcontent[endspace-1]))
		    break;
	    }
	}
#if DEBUG
	printf("text! content=%s, endspace=%d\n", validcontent, endspace);
#endif
	newbuf = (char *)malloc(sizeof(char) * (contentlen + tmplen + 1));
	strcpy(newbuf, content);
	strcpy(newbuf + contentlen, (char *)validcontent);
	if (endspace != -1)
	  endspace += contentlen;
	free(content);
	content = newbuf;
	contentlen += tmplen;
    }
    if (contentlen == 0) {
	free(content);
	return NULL;
    }

    if (endspace != -1)
	content[endspace] = '\0';
#if DEBUG
    printf("Content '%s'\n", content);
#endif
    mval = NULL;
    if (!nonnum) {
	/* convert to (list of) numbers if needed */
	char * tmpcontent = content;
	char * endptr = tmpcontent;
	double value;
	while (!((value = strtod(tmpcontent, &endptr)) == 0 &&
		 (endptr == tmpcontent))) {
#if DEBUG
	    printf("Adding double %lf, content='%s', endptr='%s'\n", value, tmpcontent, endptr);
#endif
	    if (mval == NULL)
		mval = mxCreateScalarDouble(value);
	    else {
		int numelems = mxGetNumberOfElements(mval);
		double * data = mxGetPr(mval);
		data = (double *)mxRealloc(data, (numelems + 1) * sizeof(double));
		if (!data)
		    mexErrMsgTxt("realloc failed!\n");
		data[numelems] = value;
		mxSetN(mval, numelems+1);
		mxSetPr(mval, data);
	    }
	    tmpcontent = endptr;
	    if (tmpcontent[0] != '\0' && !strchr(space, tmpcontent[0]))
		break;
	}
	if (tmpcontent[0] != '\0' && mval != NULL) {
#if DEBUG
	    printf("Attempt to parse list of doubles '%s' failed\n", tmpcontent);
#endif
	    mxDestroyArray(mval);
	    mval = NULL;
	}
    }
    /* if all else fails, it's a string */
    if (mval == NULL && strlen(content) > 0)
	mval = mxCreateString(content);

    free(content);
    return mval;
}

static void
addNamespaces(mxArray * sm, xmlNodePtr np, xmlNodePtr * stringnodes, unsigned long numstringnodes)
{
    const char * names[] = { "" };

    if (np->ns) {
        int fieldnum;
	char * href = NULL;

	fieldnum = mxGetFieldNumber(sm, "NAMESPACE");
	if (fieldnum != -1) {
	    printf("Invalid tag NAMESPACE in xml file!\n");
	} else {
	    fieldnum = mxAddField(sm, "NAMESPACE");
	}
	href = (char *)np->ns->href;
	if (href == NULL) {
	    xmlNsPtr ns = NULL;
	    printf("Searching for ns='%s'\n", np->ns->prefix);
	    ns = xmlSearchNs(np->doc, np, np->ns->prefix);
	    if (ns)
		href = (char *)ns->href;
	}
	mxSetFieldByNumber(sm, 0, fieldnum, mxCreateString((char *)href));
    }
    if (np->type == XML_ELEMENT_NODE && np->nsDef) {
	int fieldnum = mxGetFieldNumber(sm, "NSDEFS");
	mxArray * nsps = NULL;
	xmlNsPtr cur = NULL;
	if (fieldnum != -1) {
	    printf("Invalid tag NSDEFS in xml file!\n");
	} else {
	    fieldnum = mxAddField(sm, "NSDEFS");
	}
	nsps = mxCreateStructMatrix(1, 1, 0, names);
	cur = NULL;
	for (cur = np->nsDef; cur != NULL; cur = cur->next) {
	    char * prefix = NULL;
	    int afn;
	    if (cur->href == NULL || cur->href[0] == '\0')
		continue;
	    prefix = (char *)cur->prefix;
	    if (prefix == NULL)
		prefix = "DEFAULT";
	    afn = mxGetFieldNumber(nsps, prefix);
	    if (afn != -1) {
		printf("Repeated instances of namespace %s ignored.\n", prefix);
		continue;
	    } else {
		afn = mxAddField(nsps, prefix);
	    }
	    mxSetFieldByNumber(nsps, 0, afn, mxCreateString((char *)cur->href));
	}
	mxSetFieldByNumber(sm, 0, fieldnum, nsps);
    }
}

static void
addAttributes(mxArray * sm, xmlNodePtr np, xmlNodePtr * stringnodes, unsigned long numstringnodes)
{
    const char * names[] = { "" };
    int fieldnum;
    mxArray * attrs = NULL;
    xmlNodePtr cur = NULL;

    fieldnum = mxGetFieldNumber(sm, "ATTRS");
    if (fieldnum != -1) {
	printf("Invalid tag ATTRS in xml file!\n");
    } else {
	fieldnum = mxAddField(sm, "ATTRS");
    }
    attrs = NULL;
    attrs = mxCreateStructMatrix(1, 1, 0, names);
    cur = NULL;
    for (cur = (xmlNodePtr)np->properties; cur != NULL; cur = cur->next) {
	mxArray * newchild = NULL;
	int afn = mxGetFieldNumber(attrs, (char *)cur->name);
	if (afn != -1) {
	    printf("Repeated instances of attribute %s ignored.\n", cur->name);
	    continue;
	}
	afn = mxAddField(attrs, (char *)cur->name);
	newchild = xmlNodeToMxArray(cur, stringnodes, numstringnodes);
	if (newchild == NULL)
	    continue;
	if (mxGetFieldNumber(newchild, "VALUE") == -1) {
	    /* every attribute must have a value */
	    mxAddField(newchild, "VALUE");
	    mxSetField(newchild, 0, "VALUE", mxCreateString(""));
	}
	mxSetFieldByNumber(attrs, 0, afn, newchild);
    }
    mxSetFieldByNumber(sm, 0, fieldnum, attrs);
}

static double
addChildren(mxArray * sm, xmlNodePtr np, xmlNodePtr * stringnodes, unsigned long numstringnodes, double rank)
{
    xmlNodePtr cur = NULL;
    for (cur = np->children; cur != NULL; cur = cur->next) {
	mxArray * newchild = NULL;
	unsigned int fieldnum;
	mxArray * array = NULL;
	int oldlen = 0;
	mxArray * order = NULL;
	void * data = NULL;

	if (cur->type == XML_TEXT_NODE || cur->type == XML_CDATA_SECTION_NODE)
	    continue;
	if (cur->type == XML_PI_NODE) {
	    mxArray * pinst = NULL;
	    mxArray * order = NULL;

	    pinst = mxCreateCellMatrix(1, 3);
	    mxSetCell(pinst, 0, mxCreateString((char *)cur->name));
	    mxSetCell(pinst, 1, mxCreateString((char *)cur->content));
	    mxSetCell(pinst, 2, mxCreateScalarDouble(++rank));
	    addNewCellToField(sm, "PINSTS", pinst);

	    continue;
	}
	if (cur->type == XML_COMMENT_NODE &&
	    cur->content &&
	    xmlStrncmp(cur->content, (xmlChar *) "AUTOGEN:", 8) != 0) {
	    static const char * names[] = { "VALUE", "CHILDRANK" };
	    mxArray * comment = NULL;
	    mxArray * order = NULL;
	    mxArray * comments = NULL;
	    int numcomments = 0;

	    if (mxGetFieldNumber(sm, "COMMENTS") == -1) {
		mxAddField(sm, "COMMENTS");
		mxSetField(sm, 0, "COMMENTS", mxCreateStructMatrix(1, 1, 2, names));
		comments = mxGetField(sm, 0, "COMMENTS");
		numcomments = 0;
	    } else {
		mxArray * newcomments = NULL;
		int commentnum = 0;
		comments = mxGetField(sm, 0, "COMMENTS");
		numcomments = mxGetNumberOfElements(comments);
		newcomments = mxCreateStructMatrix(1, numcomments+1, 2, names);
		for (commentnum = 0; commentnum < numcomments; commentnum++) {
		    mxSetField(newcomments, commentnum, "VALUE", mxDuplicateArray(mxGetField(comments, commentnum, "VALUE")));
		    mxSetField(newcomments, commentnum, "CHILDRANK", mxDuplicateArray(mxGetField(comments, commentnum, "CHILDRANK")));
		}
		mxDestroyArray(comments);
		comments = newcomments;
		mxSetField(sm, 0, "COMMENTS", comments);
	    }
	    mxSetField(comments, numcomments, "VALUE",
		       mxCreateString((char *)cur->content));
	    mxSetField(comments, numcomments, "CHILDRANK",
		       mxCreateScalarDouble(++rank));

	    continue;
	}
	newchild = xmlNodeToMxArray(cur, stringnodes, numstringnodes);
	if (newchild == NULL)
	    continue;
	fieldnum = mxGetFieldNumber(sm, (char *)cur->name);
	if (fieldnum == -1) {
	    /* field doesn't exist yet, so add it */
	    /* create a new cell array to enclose the new child */
	    mxArray * newarray = NULL;
	    mxArray * order = NULL;

	    mxAddField(newchild, "CHILDRANK");
	    mxSetField(newchild, 0, "CHILDRANK", mxCreateScalarDouble(++rank));

	    newarray = mxCreateCellMatrix(1, 1);
	    mxSetCell(newarray, 0, newchild);
	    newchild = newarray;

	    fieldnum = mxAddField(sm, (char *)cur->name);
	    mxSetFieldByNumber(sm, 0, fieldnum, newchild);

	    continue;
	}

	array = mxGetField(sm, 0, (char *)cur->name);
	oldlen = 0;
	if (!array)
	    mexErrMsgTxt("mxGetField failed.");
	oldlen = mxGetNumberOfElements(array);
	data = mxRealloc(mxGetData(array), (oldlen + 1) * mxGetElementSize(array));
	if (!data)
	    mexErrMsgTxt("realloc failed!\n");
	mxSetN(array, oldlen + 1);
	mxSetData(array, data);

	mxAddField(newchild, "CHILDRANK");
	mxSetField(newchild, 0, "CHILDRANK", mxCreateScalarDouble(++rank));

	mxSetCell(array, oldlen, newchild);
    }
    return rank;
}

/*
 * $Log: readxml.c,v $
 * Revision 1.37  2004/05/06 21:14:09  gadde
 * fix compile abnormality on AIX
 *
 * Revision 1.36  2004/04/14 16:05:06  gadde
 * Allow namespace context to be specified as arguments.
 *
 * Revision 1.35  2003/10/20 20:42:20  michelic
 * Use xmlStrncmp for string comparison
 *
 * Revision 1.34  2003/10/13 21:31:21  gadde
 * Remove AUTOGEN comments.
 *
 * Revision 1.33  2003/04/18 16:35:13  gadde
 * New COMMENT structure.
 *
 * Revision 1.32  2003/04/16 15:20:21  gadde
 * Move declaration to top of block.
 *
 * Revision 1.31  2003/04/16 15:08:04  gadde
 * Use new "CHILDRANK" field to do what "ORDER" did before.
 * Now XML structures are much more robust when modified
 * (e.g. adding/deleting elements).
 *
 * Revision 1.30  2003/04/04 21:02:22  gadde
 * Get rid of collapse.
 *
 * Revision 1.29  2003/01/14 17:06:34  gadde
 * Add support for comments.
 *
 * Revision 1.28  2003/01/09 20:26:51  gadde
 * Add BASE field to indicate the XML file from which this struct was read.
 *
 * Revision 1.27  2003/01/02 17:23:07  gadde
 * Make shape of cell arrays consistent.
 *
 * Revision 1.26  2002/12/12 20:25:00  gadde
 * Got rid of diagnostic messages.
 *
 * Revision 1.25  2002/12/12 15:34:22  gadde
 * xpath now grabs defined namespace prefixes from root element
 *
 * Revision 1.24  2002/12/11 16:33:06  gadde
 * default namespace changes
 *
 * Revision 1.23  2002/11/08 15:59:22  gadde
 * Fixed documentation
 *
 * Revision 1.22  2002/10/07 20:38:17  gadde
 * Converted to C for your entertainment.
 *
 * Revision 1.21  2002/09/30 21:27:50  gadde
 * Variable name and scope for input filename changed.
 *
 * Revision 1.20  2002/09/25 21:21:41  michelich
 * Added Windows build instructions.
 *
 * Revision 1.19  2002/09/23 13:49:37  gadde
 * Added namespace support.
 *
 * Revision 1.18  2002/07/18 15:33:21  gadde
 * misc fixes
 *
 * Revision 1.17  2002/06/21 15:05:36  gadde
 * Collapse now correctly defaults to 0 each time readxml() is called.
 *
 * Revision 1.16  2002/06/19 18:26:46  michelich
 * Forgot to remove "return Usage()" in last revision.
 *
 * Revision 1.15  2002/06/19 18:14:46  michelich
 * Use mexErrMsgTxt() instead of return Usage() function on argument check.
 * Removed Usage() function.
 *
 * Revision 1.13  2002/06/18 19:51:52  gadde
 * Moved documentation to readxml.m.
 *
 * Revision 1.12  2002/06/14 21:24:55  gadde
 * Added ORDER information so elements in xml files can be written in
 * the same order in which they were read.
 *
 * Revision 1.8  2002/06/12 19:08:40  gadde
 * Added support for CDATA and PI nodes.
 *
 * Revision 1.5  2002/06/07 19:13:40  gadde
 * Major changes to layout of MATLAB structure -- mainly attributes
 * are now stored in an ATTRS field, and the text contents in a
 * VALUE field.  Now you can represent <elem attr="foo">bar</elem>!
 *
 * Revision 1.2  2002/06/05 18:55:28  gadde
 * Added usage comments, option to collapse single-celled cell arrays,
 * and option to add XPaths of elements not to translate numerically.
 *
 * Revision 1.1.1.1  2002/05/31 16:14:07  gadde
 *
 *
 */
