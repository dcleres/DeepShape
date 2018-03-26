function xmlret = readxml(varargin)
%READXML XML reader, using libxml2.
%
%   xml = readxml(xmlfilename)
%   xml = readxml(xmlfilename, [stringpaths...])
%   xml = readxml(xmlfilename, namespacestruct, [stringpaths...])
%
% Converts an XML file into a MATLAB struct.  Each XML element is
% represented by a struct.  If the element has any children, the
% struct will contain fields labeled by the name of the child
% element, and each field's value will be a cell array containing
% (recursively constructed) representations of all the child elements
% with the same name.
%
% If the XML element has any attributes, these are stored in the
% special field 'ATTRS', which has a cell array containing
% representations of all the attributes.
%
% If any XML element or attribute has text content, this is stored
% as a string in the special field 'VALUE'.  If this value can be
% parsed as a double-precision floating point number, it will be
% stored as a double instead of a string.  To disable this behavior
% on particular nodes, send any number of XPath expressions as arguments
% to readxml; nodes that match these paths will not be converted.  To
% disable this behavior on all nodes, use the XPath expression '//*|//@*'
% (other equivalent XPath expressions will work, but this path is matched
% explicitly by the non-compiled version of readxml, and so is faster).
%
% Any namespace prefixes used in the XPath expressions must be defined
% in 'namespacestruct', which is a structure mapping namespace prefixes
% to URIs.
%
% An example XML file 'myfile.xml':
%  <myxml>
%   <elem1 attr1="freddled">
%    <subelem attr2="gruntbuggly">subelemcontent</subelem>
%   </elem1>
%   <elem2>42</elem2>
%   <elem2>49</elem2>
%  </myxml>
%
% Sample code to convert it in MATLAB:
%  xml = readxml('myfile.xml');
%
% The value of the second 'elem2' element (49) is:
%  xml.myxml{1}.elem2{2}.VALUE
%
% The value of the 'subelem' attribute 'attr2' (gruntbuggly) is:
%  xml.myxml{1}.elem1{1}.ATTRS.attr2.VALUE
%
% To force the numbers in 'elem2' elements to be strings:
%  xml = readxml('myfile.xml', '/myxml/elem2');
%
% To force only the second one to be a string:
%  xml = readxml('myfile.xml', '/myxml/elem2[2]');

% Author: Syam Gadde (gadde@biac.duke.edu)

% CVSId = '$Id: readxml.m,v 1.14 2005/02/22 20:18:24 michelich Exp $';
% CVSRevision = '$Revision: 1.14 $';
% CVSDate = '$Date: 2005/02/22 20:18:24 $';
% CVSRCSFile = '$RCSfile: readxml.m,v $';

% This function is implemented as a MEX file.

[majorVer, minorVer] = strtok(strtok(version),'.');
majorVer = str2double(majorVer);
minorVer = str2double(strtok(minorVer,'.'));
if majorVer < 6 | (majorVer == 6 & minorVer < 5)
  errmsg = 'For Matlab versions earlier than 6.5 (R13), you need to compile the MEX file readxml.c (requires libxml2, and is much faster)';
  error(errmsg);
else
  warning('readxml:compile', sprintf('You are using the non-compiled version of readxml which is very slow.\nIf you have libxml2 available, please consider compiling readxml.c.'));
end
clear majorVer minorVer

try
  props = java.lang.System.getProperties;
catch
  errmsg = '.m version of readxml requires Java, which is not enabled.  Otherwise you will need to compile the MEX file readxml.c (requires libxml2, but does not require Java, and is much faster)';
  error(errmsg);
end

if nargin < 1
  errmsg = 'Not enough arguments!'; error(errmsg);
end

if ~ischar(varargin{1})
  errmsg = 'First argument must be a filename!'; error(errmsg);
end

xmlfilename = varargin{1};
nsdecls = [];
if nargin > 1 & isstruct(varargin{2})
  nsdecls = varargin{2};
end
if isempty(nsdecls)
  stringpaths = varargin(2:end);
else
  stringpaths = varargin(3:end);
end

numpaths = length(stringpaths);
for pathnum = 1:numpaths
  stringpath = stringpaths{pathnum};
  if ~ischar(stringpath)
    errmsg = 'All arguments must be strings!'; error(errmsg);
  end
end

numconvert = 1;
if any(strmatch('//*|//@*', stringpaths, 'exact'))
  numconvert = 0;
  stringpaths = {};
end

domdoc = xmlread(xmlfilename);

if isempty(domdoc)
  errmsg = sprintf('Error parsing XML file %s!', xmlfilename); error(errmsg);
end

stringnodes = parseXPaths(stringpaths, domdoc, nsdecls);
numstringnodes = length(stringnodes);

% convert DOM Node recursively to struct
xmlret = [];
nsmap = [];
nsmap.xmlns = 'http://www.w3.org/2000/xmlns/';
queue = { { 'xmlret', domdoc, nsmap } };
while length(queue) > 0
  % shift one element off queue
  [ structname, node, nsmap ] = deal(queue{1}{:});
  queue(1) = [];

  rank = 0;

  structcopy = eval(structname);

  XML_ELEMENT_NODE = 1;
  XML_ATTRIBUTE_NODE = 2;
  XML_TEXT_NODE = 3;
  XML_PI_NODE = 4;
  XML_CDATA_SECTION_NODE = 7;
  XML_COMMENT_NODE = 8;
  XML_DOCUMENT_NODE = 9;

  nodetype = node.getNodeType;

  if ~any(nodetype == [XML_ELEMENT_NODE XML_ATTRIBUTE_NODE XML_TEXT_NODE XML_PI_NODE XML_CDATA_SECTION_NODE XML_DOCUMENT_NODE])
    return
  end

  % addAttributes
  if node.hasAttributes
    if isfield(structcopy, 'ATTRS')
      errmsg = 'Invalid tag ATTRS in XML file!'; error(errmsg);
    end
    if isfield(structcopy, 'NSDEFS')
      errmsg = 'Invalid tag NSDEFS in XML file!'; error(errmsg);
    end
    attrscopy = [];
    nsdefscopy = [];
    domattrs = node.getAttributes;
    attrs = struct('ns', {}, 'localname', {}, 'value', {});
    % do some preprocessing (and parse namespace attrs while we're at it)
    for attrnum = 1:domattrs.getLength
      domattr = domattrs.item(attrnum-1);
      attrname = cindex(cell(domattr.getNodeName),1); % quick char conv
      attrvalue = cindex(cell(domattr.getNodeValue),1); % quick char conv
      colonpos = findstr(attrname, ':');
      attrprefix = '';
      if ~isempty(colonpos)
        attrprefix = attrname(1:colonpos-1);
        attrname(1:colonpos) = [];
      end
      if isempty(attrprefix) & strcmp(attrname, 'xmlns')
        if isfield(nsdefscopy, 'DEFAULT')
          warning(sprintf('Repeated instances of default namespace %s ignored.', attrname));
          continue
        end
        if isempty(attrvalue)
          % xmlns="" -- default namespace is unset 
          if isfield(nsmap, 'DEFAULT')
            nsmap = rmfield(nsmap, 'DEFAULT')
          end
        else
          nsdefscopy.DEFAULT = attrvalue;
          nsmap = setfield(nsmap, 'DEFAULT', attrvalue);
        end
        continue
      end
      attrns = [];
      % no default namespace for attributes
      if ~isempty(attrprefix)
        if isfield(nsmap, attrprefix)
          attrns = getfield(nsmap, attrprefix);
        end
      end
      if strcmp(attrns, 'http://www.w3.org/2000/xmlns/')
        if isfield(nsdefscopy, attrname)
          warning(sprintf('Repeated instances of namespace %s ignored.', attrname));
          continue
        end
        nsdefscopy = setfield(nsdefscopy, attrname, attrvalue);
        nsmap = setfield(nsmap, attrname, attrvalue);
        continue
      end
      attrnum = length(attrs) + 1;
      attrs(attrnum).domnode = domattr;
      attrs(attrnum).ns = attrns;
      attrs(attrnum).localname = attrname;
      attrs(attrnum).value = attrvalue;
    end
    % now do non-nsdecl attrs
    for attrnum = 1:length(attrs);
      domattr = attrs(attrnum).domnode;
      attrns = attrs(attrnum).ns;
      attrname = attrs(attrnum).localname;
      attrvalue = attrs(attrnum).value;
      if isfield(attrscopy, attrname)
        oldattr = getfield(attrscopy, attrname);
        if ~isempty(oldattr) && strcmp(attrns, getfield(oldattr, 'NAMESPACE'))
          warning(sprintf('Repeated instances of attribute %s ignored.', attrname));
          continue
        end
      end
      if numconvert & ~isempty(attrvalue)
        keepstring = 0;
        for strnnum = 1:numstringnodes
          if domattr.equals(stringnodes(strnnum))
            keepstring = 1;
            break
          end
        end
        if ~keepstring
          attrvalue = convertNum(attrvalue);
        end
      end
      if isempty(attrns)
        attrscopy = setfield(attrscopy, attrname, struct('VALUE', {attrvalue}));
      else
        attrscopy = setfield(attrscopy, attrname, struct('VALUE', {attrvalue}, 'NAMESPACE', {attrns}));
      end
    end
    if ~isempty(attrscopy)
      structcopy.ATTRS = attrscopy;
    end
    if ~isempty(nsdefscopy)
      structcopy.NSDEFS = nsdefscopy;
    end
  end

  % addNamespace
  if nodetype ~= XML_DOCUMENT_NODE
    if isfield(structcopy, 'NAMESPACE')
      errmsg = 'Invalid tag NAMESPACE in XML file!'; error(errmsg);
    end
    prefix = node.getPrefix;
    structcopy.NAMESPACE = [];
    if isempty(prefix)
      if isfield(nsmap, 'DEFAULT')
        structcopy.NAMESPACE = nsmap.DEFAULT;
      end
    else
      if isfield(nsmap, prefix)
        structcopy.NAMESPACE = getfield(nsmap, prefix);
      end
    end
  end

  % addText
  content = getNodeContent(node);
  if numconvert & ~isempty(content)
    keepstring = 0;
    for strnnum = 1:numstringnodes
      if node.equals(stringnodes(strnnum))
        keepstring = 1;
        break
      end
    end
    if ~keepstring
      content = convertNum(content);
    end
  end
  if ~isempty(content)
    if isfield(structcopy, 'VALUE')
      errmsg = 'Invalid tag VALUE in XML file!'; error(errmsg);
    end
    structcopy.VALUE = content;
    if nodetype == XML_ELEMENT_NODE
      if isfield(structcopy, 'VALUECHILDRANK')
        errmsg = 'Invalid tag VALUECHILDRANK in XML file!'; error(errmsg);
      end
      rank = rank + 1;
      structcopy.VALUECHILDRANK = rank;
    end
  end

  % addChildren
  childnodelist = node.getChildNodes;
  for childnum = 0:childnodelist.getLength-1;
    childnode = childnodelist.item(childnum);

    childtype = childnode.getNodeType;

    % will take care of these in a later pass
    if any(childtype == [XML_TEXT_NODE XML_CDATA_SECTION_NODE])
      continue
    end

    childname = cindex(cell(childnode.getNodeName),1); % quick char conv

    colonpos = findstr(childname, ':');
    if ~isempty(colonpos)
      childname(1:colonpos) = [];
    end

%    {childname, childtype, childcontent}

    if childtype == XML_PI_NODE
      childcontent = cindex(cell(childnode.getNodeValue),1); % quick char conv
      if ~isfield(structcopy, 'PINSTS')
        structcopy.PINSTS = {};
      end
      rank = rank + 1;
      structcopy.PINSTS{end+1} = { childname, childcontent, rank };
      continue
    elseif childtype == XML_COMMENT_NODE
      childcontent = cindex(cell(childnode.getNodeValue),1); % quick char conv
      if length(childcontent) >= 8 & strcmp(childcontent(1:8), 'AUTOGEN:')
        continue;
      end
      if ~isfield(structcopy, 'COMMENTS')
        structcopy.COMMENTS = struct('VALUE', {}, 'CHILDRANK', {});
      end
      rank = rank + 1;
      structcopy.COMMENTS(end+1) = struct('VALUE', { childcontent }, 'CHILDRANK', {rank});
      continue
    end

    if strcmp(childname, 'PINSTS')
      errmsg = 'Invalid tag PINSTS in XML file!'; error(errmsg)
    end
    if strcmp(childname, 'COMMENTS')
      errmsg = 'Invalid tag COMMENTS in XML file!'; error(errmsg);
    end

    newchild = [];
    rank = rank + 1;
    newchild.CHILDRANK = rank;
    cells = {};
    if isfield(structcopy, childname)
      eval(['cells = structcopy.' childname ';']);
    end
    cells{end+1} = newchild;
    eval(['structcopy.' childname ' = cells;']);
    queue{end+1} = {[structname '.' childname '{' num2str(length(cells)) '}'], childnode, nsmap};
  end

  eval([structname ' = structcopy;']);
end

if isfield(xmlret, 'BASE')
  errmsg = 'Invalid tag BASE in XML file!';
  error(errmsg);
end
xmlret.BASE = xmlfilename;

return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function content = getNodeContent(node)

contentobj = java.lang.String;
contentlen = 0;
precdatalen = NaN;
postcdatalen = 0;
trimbegin = 1;
minlen = 0;

childnodelist = node.getChildNodes;
numchildren = childnodelist.getLength;
for childnum = 0:numchildren-1;
  childnode = childnodelist.item(childnum);

  childtype = childnode.getNodeType;
  if childtype ~= 3 & childtype ~= 7 % neither TEXT nor CDATA
    continue
  end

  childcontentobj = childnode.getNodeValue;
  childcontentlen = childcontentobj.length;
  contentobj = contentobj.concat(childcontentobj);
  contentlen = contentlen + childcontentlen;
  if childtype == 7 % CDATA
    if isnan(precdatalen)
      precdatalen = contentlen;
    end
    postcdatalen = 0;
  else
    postcdatalen = postcdatalen + childcontentlen;
  end
end

% see if we can trim space from beginning and/or end
if contentlen == 0
  % no content
  content = '';
elseif isnan(precdatalen)
  % no CDATA, so trim both sides
  content = cindex(cell(contentobj.trim),1); % quick char conv
elseif precdatalen == 0
  if postcdatalen == 0
    % CDATA at both ends, don't trim
    content = cindex(cell(contentobj),1); % quick char conv
  else
    % CDATA at beginning, just trim end
    notrimlen = contentlen - postcdatalen;
    content = cindex(cell(contentobj.substring(0, notrimlen).concat(java.lang.String('*').concat(contentobj.substring(notrimlen)).trim.substring(1))),1);
  end
else
  % we need to trim beginning
  prestrobj = contentobj.substring(0, precdatalen).concat(java.lang.String('*')).trim;
  prestrlen = prestrobj.length;
  if postcdatalen == 0
    % CDATA at end, so don't trim end
    content = cindex(cell(prestrobj.substring(0,prestrlen-1).concat(contentobj.substring(precdatalen))),1);
  else
    % CDATA in middle, trim end too
    notrimlen = contentlen - postcdatalen;
    content = cindex(cell(prestrobj.substring(0,prestrlen-1).concat(contentobj.substring(precdatalen, notrimlen)).concat(java.lang.String('*').concat(contentobj.substring(notrimlen)).trim.substring(1))),1);
  end
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function newcontent=convertNum(content)

% simple check to get rid of common case
if isempty(content) | isletter(content(1))
  newcontent = content;
  return
end
spaces = isspace(content);
tmpcontent = content;
tmpcontent(spaces) = sprintf('\n');
strs = splitstr(tmpcontent);
nums = str2double(strs');
if ~any(isnan(nums))
  newcontent = nums;
else
  newcontent = content;
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% An XPath node is a structure with the fields xptype and data.
% xptype may be 'element', 'attribute', 'text', 'processing-instruction',
% 'text', 'comment', 'root'.
% If xptype is 'namespace', then data is a struct with the fields
% domparent (pointing to the parent element's DOM node), prefix
% and uri (the prefix and URI for this namespace declaration).
% For any other xptype, data is a struct containing the
% field domnode, which points to the DOM node corresponding to
% this XPath node.
% Nodes with xptype 'element' or 'attribute' have the following
% additional fields:
%   localname
%   prefix
%   nsuri
% Nodes with xptype 'element' have the following additional fields:
%   defaultns
%   nsdecls
% All of these fields are set automatically if you use createXPathNode,
% createXPathNodeNS, getXPathNodeChildren and getXPathNodeAttributes.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function xpnode=createXPathNode(domnode)
xptype = '';
domtype = domnode.getNodeType;
switch domtype
 case 1
  xptype = 'element';
 case 2
  xptype = 'attribute';
 case 3
  xptype = 'text';
 case 4
  xptype = 'processing-instruction';
 case 7
  xptype = 'text';
 case 8
  xptype = 'comment';
 case 9
  xptype = 'root';
 otherwise
  errmsg = ['Context nodes of DOM type ' num2str(domtype) ' not supported'];
  error(errmsg);
end
if domtype == 1 | domtype == 2  % element or attribute
  nsdecls = struct([]);
  % create in-scope nsdecls
  defaultns = [];
  curdomnode = [];
  if domtype == 1 % element
    curdomnode = domnode.getParentNode;
  else % attribute
    curdomnode = domnode.getOwnerElement;
  end
  ancestors = struct('xptype', {}, 'data', {});
  while ~isempty(curdomnode)
    ancestors(end+1) = curdomnode;
    curdomnode = curdomnode.getParentNode;
  end
  while length(ancestors) > 0
    curdomnode = ancestors(end);
    ancestors(end) = [];
    nnm = curdomnode.getAttributes;
    nnmlen = nnm.getLength;
    for attrnum=0:nnmlen-1;
      attr = nnm.item(attrnum);
      attrname = attr.getName;
      attrvalue = attr.getValue;
      if strmatch('xmlns', attrname)
        if length(attrname) == 5
          defaultns = attrvalue;
        elseif length(attrname) >= 6 & attrname(6) == ':'
          nsdecls = setfield(nsdecls, attrname(7:end), attr.getValue);
        end
      end
    end
  end
  xpnode = createXPathNodeNS(domnode, defaultns, nsdecls);
else
  xpnode = struct('xptype', xptype, 'data', struct('domnode', domnode));
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function xpnode=createXPathNodeNS(domnode, defaultns, nsdecls)
xptype = '';
domtype = domnode.getNodeType;
switch domtype
 case 1
  xptype = 'element';
 case 2
  xptype = 'attribute';
 case 3
  xptype = 'text';
 case 4
  xptype = 'processing-instruction';
 case 7
  xptype = 'text';
 case 8
  xptype = 'comment';
 case 9
  xptype = 'root';
 otherwise
  errmsg = ['Context nodes of DOM type ' num2str(domtype) ' not supported'];
  error(errmsg);
end
if domtype == 1 % element
  nnm = domnode.getAttributes;
  nnmlen = nnm.getLength;
  for attrnum=0:nnmlen-1;
    attr = nnm.item(attrnum);
    attrname = cindex(cell(attr.getName),1); % quick char conv
    attrvalue = cindex(cell(attr.getValue),1); % quick char conv
    if strmatch('xmlns', attrname)
      if length(attrname) == 5
        % default namespace
        defaultns = attrvalue;
      elseif length(attrname) >= 6 & attrname(6) == ':'
        nsdecls = setfield(nsdecls, attrname(7:end), attrvalue);
      end
    end
  end
end
if domtype == 1 | domtype == 2  % element or attribute
  prefix = [];
  localname = cindex(cell(domnode.getNodeName),1); % quick char conv
  comps = splitstr(localname, ':');
  if length(comps) > 1
    prefix = comps{1};
    localname = comps{2};
  end
  nsuri = [];
  if isempty(prefix)
    if domtype == 1 % default namespace only applies to elements
      nsuri = defaultns;
    end
  elseif isfield(nsdecls, prefix)
    nsuri = getfield(nsdecls, prefix);
  end
  if domtype == 1
    xpnode = struct('xptype', xptype, 'data', struct('domnode', domnode, 'localname', localname, 'prefix', prefix, 'nsuri', nsuri, 'defaultns', defaultns, 'nsdecls', nsdecls));
  else
    xpnode = struct('xptype', xptype, 'data', struct('domnode', domnode, 'localname', localname, 'prefix', prefix, 'nsuri', nsuri));
  end
else
  xpnode = struct('xptype', xptype, 'data', struct('domnode', domnode));
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function nodelist=getXPathNodeChildren(xpnode)
nodelist = struct('xptype', {}, 'data', {});
isroot = 0;
if strcmp(xpnode.xptype, 'root')
  isroot = 1;
end
if ~isroot & ~strcmp(xpnode.xptype, 'element')
  return
end
defaultns = [];
nsdecls = [];
if ~isroot
  defaultns = xpnode.data.defaultns;
  nsdecls = xpnode.data.nsdecls;
end
domnodelist = xpnode.data.domnode.getChildNodes;
listlen = domnodelist.getLength;
for nodenum = 0:listlen-1
  curdomnode = domnodelist.item(nodenum);
  nodelist(end+1) = createXPathNodeNS(curdomnode, defaultns, nsdecls);
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function nodelist=getXPathNodeAttributes(xpnode)
nodelist = struct('xptype', {}, 'data', {});
if ~strcmp(xpnode.xptype, 'element')
  return
end
defaultns = xpnode.data.defaultns;
nsdecls = xpnode.data.nsdecls;
nnm = xpnode.data.domnode.getAttributes;
nnmlen = nnm.getLength;
for attrnum=0:nnmlen-1;
  domattr = nnm.item(attrnum);
  attrname = cindex(cell(domattr.getName),1); % quick char conv
  % skip namespace nodes
  if strmatch('xmlns', attrname) & (length(attrname) < 6 | attrname(6) == ':'), continue; end
  nodelist(end+1) = createXPathNodeNS(domattr, defaultns, nsdecls);
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function outnodes=uniqueXPathNodes(innodes)
inlen = length(innodes);
if inlen == 1 | inlen == 0, outnodes = innodes; return; end
types = {innodes.xptype};
[utypes, m2u, u2m] = unique(types);
numutypes = length(utypes);
delthese = [];
for typenum = 1:numutypes
  minds = find(u2m == typenum);
  numinds = length(minds);
  for indnum = 1:numinds
    ival = innodes(indnum).data;
    for checknum = indnum+1:numinds
      cval = innodes(checknum).data;
      if isequal(ival, cval)
        delthese(end+1) = indnum;
        break;
      end
    end
  end
end
outnodes = innodes(setdiff(1:inlen, delthese));
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function nodelist=getNodesOnAxis(contextnode, axisname)
% contextnode is an XPath node
nodelist = struct('xptype', {}, 'data', {});
xptype = contextnode.xptype;
if strcmp(xptype, 'namespace')
  % special case -- only XPath node that doesn't wrap a DOM node
  switch axisname
   case 'parent'
    nodelist = struct('xptype', 'element', 'data', struct('domnode', contextnode.data.domparent));
    return
   case {'attribute','child','descendant','descendant-or-self','following-sibling','namespace','preceding-sibling'}
    % empty
    return
   case {'following','preceding'}
    contextnode = struct('xptype', 'element', 'data', struct('domnode', contextnode.data.domparent));
    % fall through
  end
end
% at this point context node is guaranteed to wrap a DOM node
% (i.e. it's not a XPath namespace node)
switch axisname
 case 'child'
  nodelist = getXPathNodeChildren(contextnode);
 case 'descendant'
  queue = [contextnode];
  while ~isempty(queue)
    curnode = queue(end);
    queue(1) = [];
    children = getNodesOnAxis(curnode, 'child');
    nodelist(end+1:end+length(children)) = children;
    queue(end+1:end+length(children)) = children;
  end
 case 'parent'
  if strcmp(xptype, 'attribute')
    nodelist = createXPathNode(contextnode.data.domnode.getOwnerElement);
  else
    nodelist = createXPathNode(contextnode.data.domnode.getParentNode);
  end
 case 'ancestor'
  curnode = getNodesOnAxis(contextnode, 'parent'); % in case contextnode is an attribute
  % now curnode must be an element or document node
  curdomnode = curnode.data.domnode;
  while ~isempty(curdomnode)
    nodelist(end+1) = createXPathNode(curdomnode);
    curdomnode = curdomnode.getParentNode;
  end
 case 'following-sibling'
  curdomnode = contextnode.data.domnode;
  curdomnode = curdomnode.getNextSibling;
  while ~isempty(curdomnode)
    nodelist(end+1) = createXPathNode(curdomnode);
    curdomnode = curdomnode.getNextSibling;
  end
 case 'preceding-sibling'
  curdomnode = contextnode.data.domnode;
  curdomnode = curdomnode.getPreviousSibling;
  while ~isempty(curdomnode)
    nodelist(end+1) = createXPathNode(curdomnode);
    curdomnode = curdomnode.getPreviousSibling;
  end
 case 'following'
  if strcmp(xptype, 'attribute')
    contextnode = createXPathNode(contextnode.nvalue.getOwnerElement);
  end
  nodelist = getNodesOnAxis(contextnode, 'following-sibling');
 case 'preceding'
  if strcmp(xptype, 'attribute')
    contextnode = createXPathNode(contextnode.nvalue.getOwnerElement);
  end
  nodelist = getNodesOnAxis(contextnode, 'preceding-sibling');
 case 'attribute'
  if strcmp(xptype, 'element')
    nodelist = getXPathNodeAttributes(contextnode);
  end
 case 'namespace'
  if strcmp(xptype, 'element')
    nsdecls = contextnode.nsdecls;
    prefixes = fieldnames(nsdecls);
    numprefixes = length(prefixes);
    for prefixnum=1:numprefixes
      prefix = prefixes{prefixnum};
      nodelist(end+1) = struct('xptype', 'namespace', 'data', struct('prefix', {prefix}, 'uri', {getfield(nsdecls, prefix)}, 'domparent', contextnode.data.domnode));
    end
  end
 case 'self'
  nodelist = contextnode;
 case 'descendant-or-self'
  nodelist = getNodesOnAxis(contextnode, 'descendant');
  nodelist(end+1) = contextnode;
 case 'ancestor-or-self'
  nodelist = getNodesOnAxis(contextnode, 'ancestor');
  nodelist(end+1) = contextnode;
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchnodes=parseXPaths(inpaths, domcontextnode, nsdecls)
global errmsg;
matchnodes = [];
contextnode = createXPathNode(domcontextnode);
context = struct('node', contextnode, 'position', 1, 'size', 1, 'vars', [], 'nsdecls', nsdecls);
tokenpaths = convertXPaths(inpaths);
numpaths = length(tokenpaths);
for pathnum = 1:numpaths
  tokenpath = tokenpaths{pathnum};
  errmsg = '(no errors reported)';
  [mend, mobj] = xpparseExpr(tokenpath, 1, context);
  if mend == 0
    errmsg = ['Error parsing Expr in XPath string "' tokenpath.value sprintf('"\n') errmsg];
    error(errmsg);
  elseif mend ~= length(tokenpath)
    errmsg = sprintf(['Garbage at end of XPath: "' tokenpath(mend:end).value '".\nPossible errors:\n' errmsg]);
    error(errmsg);
  elseif ~strcmp(mobj.type, 'node-set')
    errmsg = sprintf(['XPath "' tokenpath.value '" doesn''t return a node-set.\nPossible errors:\n' errmsg]);
    error(errmsg);
  end
  numnodes = length(mobj.value);
  if numnodes > 0
    if isempty(matchnodes)
      matchnodes = mobj.value.data.domnode;
    else
      data = [mobj.value.data];
      matchnodes = [matchnodes data.domnode];
    end
  end
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseExpr(tokenpath, tokenstart, context)
[mend, mobj] = xpparseOrExpr(tokenpath, tokenstart, context);
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseOrExpr(tokenpath, tokenstart, context)
%[21]    OrExpr    ::=    AndExpr
%   | OrExpr 'or' AndExpr
%disp(['OrExpr: ' tokenpath(tokenstart:end).value]);
[mend, mobj] = xpparseAndExpr(tokenpath, tokenstart, context);
if mend == 0, return; end
tokenpathlen = length(tokenpath);
while mend + 1 <= tokenpathlen & strcmp(tokenpath(mend+1).value, 'or')
  tokenstart = mend+2;
  [mend2, mobj2] = xpparseAndExpr(tokenpath, tokenstart, context);
  if mend2 == 0, return; end
  if ~strcmp(mobj.type, 'boolean')
    mobj.value = xpfunc_boolean(mobj, context);
    mobj.type = 'boolean';
  end
  mend = mend2;
  mobj2.value = xpfunc_boolean(mobj2, context);
  mobj.value = mobj.value | mobj2.value; % do the actual 'or'
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseAndExpr(tokenpath, tokenstart, context)
%[22]    AndExpr    ::=    EqualityExpr
%   | AndExpr 'and' EqualityExpr
%disp(['AndExpr: ' tokenpath(tokenstart:end).value]);
[mend, mobj] = xpparseEqualityExpr(tokenpath, tokenstart, context);
if mend == 0, return; end
tokenpathlen = length(tokenpath);
while mend + 1 <= tokenpathlen & strcmp(tokenpath(mend+1).value, 'and')
  tokenstart = mend+2;
  [mend2, mobj2] = xpparseEqualityExpr(tokenpath, tokenstart, context);
  if mend2 == 0, return; end
  if ~strcmp(mobj.type, 'boolean')
    mobj.value = xpfunc_boolean(mobj, context);
    mobj.type = 'boolean';
  end
  mend = mend2;
  mobj2.value = xpfunc_boolean(mobj2, context);
  mobj.value = mobj.value & mobj2.value; % do the actual 'and'
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseEqualityExpr(tokenpath, tokenstart, context)
%[23]    EqualityExpr    ::=    RelationalExpr
%   | EqualityExpr '=' RelationalExpr
%   | EqualityExpr '!=' RelationalExpr
%disp(['EqualityExpr: ' tokenpath(tokenstart:end).value]);
try [mend, mobj] = xpparseRelationalExpr(tokenpath, tokenstart, context);
catch mend = 0; mobj= [];
end
if mend == 0, return; end
tokenpathlen = length(tokenpath);
cmpop = '';
if mend + 1 <= tokenpathlen
  cmpop = tokenpath(mend+1).value;
end
while mend + 1 <= tokenpathlen & ...
      (strcmp(cmpop, '=') | strcmp(cmpop, '!='))
  tokenstart = mend+2;
  [mend2, mobj2] = xpparseRelationalExpr(tokenpath, tokenstart, context);
  if mend2 == 0, return; end
  mend = mend2;
  % save types
  typea = mobj.type;
  typeb = mobj2.type;
  % If we are comparing a node-set to boolean, convert node-set to boolean.
  % If we are comparing a node-set to anything else, unfold and convert later.
  if strcmp(typea, 'node-set')
    if strcmp(typeb, 'boolean')
      typea = 'boolean';
      mobj = xpfunc_boolean(mobj, context);
    else
      mobj = mobj.value; % unfold
    end
  elseif strcmp(typeb, 'node-set')
    if strcmp(typea, 'boolean')
      typea = 'boolean';
      mobj2 = xpfunc_boolean(mobj2, context);
    else
      mobj2 = mobj2.value; % unfold
    end
  end
  % mobj1 and mobj2 may now be either XPath objects or DOM node arrays (for
  % node-sets)
  flip = 0;
  if strcmp(cmpop, '!='), flip = 1; end
  found = false;
  for obja=mobj
    for objb=mobj2
      % for node set nodes, get string-value
      if strcmp(typea, 'node-set')
        obja = xpfunc_string(struct('type', {'node-set'}, 'value', {obja}), context);
      end
      if strcmp(typeb, 'node-set')
        objb = xpfunc_string(struct('type', {'node-set'}, 'value', {objb}), context);
      end
      % do comparisons
      if strcmp(typea, 'boolean')
        if ~strcmp(typeb, 'boolean')
          objb = xpfunc_boolean(objb, context);
        end
        found = (obja.value == objb.value);
      elseif strcmp(typeb, 'boolean')
        obja = xpfunc_boolean(objb, context);
        found = (obja.value == objb.value);
      elseif strcmp(typea, 'number')
        if ~strcmp(typeb, 'number')
          objb = xpfunc_number(objb, context);
        end
        found = (obja.value == objb.value);
      elseif strcmp(typeb, 'number')
        obja = xpfunc_number(objb, context);
        found = (obja.value == objb.value);
      elseif strcmp(typea, 'string')
        if ~strcmp(typeb, 'string')
          objb = xpfunc_string(objb, context);
        end
        found = strcmp(obja.value, objb.value);
      elseif strcmp(typeb, 'string')
        obja = xpfunc_string(objb, context);
        found = (obja.value == objb.value);
      end
      if flip, found = ~found; end
      if found, break; end
    end
    if found, break; end
  end
  mobj = [];
  mobj.type = 'boolean';
  if found
    mobj.value = true;
  else
    mobj.value = false;
  end
  if mend + 1 <= tokenpathlen
    cmpop = tokenpath(mend+1).value;
  end
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseRelationalExpr(tokenpath, tokenstart, context)
%[24]    RelationalExpr    ::=    AdditiveExpr
%   | RelationalExpr '<' AdditiveExpr
%   | RelationalExpr '>' AdditiveExpr
%   | RelationalExpr '<=' AdditiveExpr
%   | RelationalExpr '>=' AdditiveExpr
%disp(['RelationalExpr: ' tokenpath(tokenstart:end).value]);
try [mend, mobj] = xpparseAdditiveExpr(tokenpath, tokenstart, context);
catch mend = 0; mobj= [];
end
if mend == 0, return; end
tokenpathlen = length(tokenpath);
cmpop = '';
if mend + 1 <= tokenpathlen
  cmpop = tokenpath(mend+1).value;
end
while mend + 1 <= tokenpathlen & ...
      strmatch(cmpop, strvcat('<', '>', '<=', '>='), 'exact')
  tokenstart = mend+2;
  [mend2, mobj2] = xpparseAdditiveExpr(tokenpath, tokenstart, context);
  if mend2 == 0, return; end
  mend = mend2;
  % save types
  typea = mobj.type;
  typeb = mobj2.type;
  % If we are comparing a node-set to boolean, convert node-set to boolean.
  % If we are comparing a node-set to anything else, unfold and convert later.
  if strcmp(typea, 'node-set')
    if strcmp(typeb, 'boolean')
      typea = 'boolean';
      mobj = xpfunc_boolean(mobj, context);
    else
      mobj = mobj.value; % unfold
    end
  elseif strcmp(typeb, 'node-set')
    if strcmp(typea, 'boolean')
      typea = 'boolean';
      mobj2 = xpfunc_boolean(mobj2, context);
    else
      mobj2 = mobj2.value; % unfold
    end
  end
  % mobj1 and mobj2 may now be either XPath objects or DOM node arrays (for
  % node-sets)
  found = false;
  for obja=mobj
    for objb=mobj2
      % for node set nodes, get string-value
      if strcmp(typea, 'node-set')
        obja = xpfunc_string(struct('type', {'node-set'}, 'value', {obja}), context);
      end
      if strcmp(typeb, 'node-set')
        objb = xpfunc_string(struct('type', {'node-set'}, 'value', {objb}), context);
      end
      % convert everything to a number
      if ~strcmp(typea, 'number')
        obja = xpfunc_number(obja, context);
      end
      if ~strcmp(typeb, 'number')
        objb = xpfunc_number(objb, context);
      end
      % do comparisons
      switch cmpop
       case '<', found = (obja.value < objb.value);
       case '>', found = (obja.value > objb.value);
       case '<=', found = (obja.value <= objb.value);
       case '>=', found = (obja.value >= objb.value);
      end
      if found, break; end
    end
    if found, break; end
  end
  mobj = [];
  mobj.type = 'boolean';
  if found
    mobj.value = true;
  else
    mobj.value = false;
  end
  if mend + 1 <= tokenpathlen
    cmpop = tokenpath(mend+1).value;
  end
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseAdditiveExpr(tokenpath, tokenstart, context)
%[25]    AdditiveExpr    ::=    MultiplicativeExpr
%   | AdditiveExpr '+' MultiplicativeExpr
%   | AdditiveExpr '-' MultiplicativeExpr
%disp(['AdditiveExpr: ' tokenpath(tokenstart:end).value]);
try [mend, mobj] = xpparseMultiplicativeExpr(tokenpath, tokenstart, context);
catch mend = 0; mobj= [];
end
if mend == 0, return; end
tokenpathlen = length(tokenpath);
cmpop = '';
if mend + 1 <= tokenpathlen
  cmpop = tokenpath(mend+1).value;
end
while mend + 1 <= tokenpathlen & (strcmp(cmpop, '+') | strcmp(cmpop, '-'))
  tokenstart = mend+2;
  [mend2, mobj2] = xpparseMultiplicativeExpr(tokenpath, tokenstart, context);
  if mend2 == 0, return; end
  mend = mend2;
  % convert everything to a number
  if ~strcmp(mobj.type, 'number')
    mobj = xpfunc_number(mobj, context);
  end
  if ~strcmp(mobj2.type, 'number')
    mobj2 = xpfunc_number(mobj2, context);
  end
  mobj.type = 'number';
  switch cmpop
   case '+', mobj.value = mobj.value + mobj2.value;
   case '-', mobj.value = mobj.value - mobj2.value;
  end
  if mend + 1 <= tokenpathlen
    cmpop = tokenpath(mend+1).value;
  end
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseMultiplicativeExpr(tokenpath, tokenstart, context)
%[26]    MultiplicativeExpr    ::=    UnaryExpr
%   | MultiplicativeExpr MultiplyOperator UnaryExpr
%   | MultiplicativeExpr 'div' UnaryExpr
%   | MultiplicativeExpr 'mod' UnaryExpr
%disp(['MultiplicativeExpr: ' tokenpath(tokenstart:end).value]);
try [mend, mobj] = xpparseUnaryExpr(tokenpath, tokenstart, context);
catch mend = 0; mobj= [];
end
if mend == 0, return; end
tokenpathlen = length(tokenpath);
cmpop = '';
if mend + 1 <= tokenpathlen
  cmpop = tokenpath(mend+1).value;
end
while mend + 1 <= tokenpathlen & strmatch(cmpop, strvcat('*', 'div', 'mod'), 'exact')
  if strcmp(cmpop, '*') & ...
        ~strcmp(tokenpath(mend+1).gtype, 'MultiplyOperator')
    break;
  end
  tokenstart = mend+2;
  [mend2, mobj2] = xpparseUnaryExpr(tokenpath, tokenstart, context);
  if mend2 == 0, return; end
  mend = mend2;
  % convert everything to a number
  if ~strcmp(mobj.type, 'number')
    mobj = xpfunc_number(mobj, context);
  end
  if ~strcmp(mobj2.type, 'number')
    mobj2 = xpfunc_number(mobj2, context);
  end
  mobj.type = 'number';
  switch cmpop
   case '*'
    mobj.value = mobj.value * mobj2.value;
   case 'div'
    mobj.value = mobj.value / mobj2.value;
   case 'mod'
    mobj.value = mobj.value - (fix(mobj.value / mobj2.value) * mobj2.value);
  end
  if mend + 1 <= tokenpathlen
    cmpop = tokenpath(mend+1).value;
  end
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseUnaryExpr(tokenpath, tokenstart, context)
%[27]    UnaryExpr    ::=    UnionExpr
%   | '-' UnaryExpr
%disp(['UnaryExpr: ' tokenpath(tokenstart:end).value]);
mend = tokenstart;
tokenpathlen = length(tokenpath);
found = 0;
while mend + found <= tokenpathlen & strcmp(tokenpath(mend + found).value, '-')
  found = found + 1;
  mend = mend + 1;
end
try [mend, mobj] = xpparseUnionExpr(tokenpath, mend, context);
catch mend = 0; mobj= [];
end
if mend == 0, return; end
if found > 0
  % convert to a number
  if ~strcmp(mobj.type, 'number')
    mobj = xpfunc_number(mobj, context);
  end
  % even number of unary '-'s are a no-op (except for numeric conversion)
  if mod(found, 2) == 1
    mobj.value = -1 * mobj.value;
  end
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseUnionExpr(tokenpath, tokenstart, context)
%[18]    UnionExpr    ::=    PathExpr
%   | UnionExpr '|' PathExpr
%disp(['UnionExpr: ' tokenpath(tokenstart:end).value]);
global errmsg;
[mend, mobj] = xpparsePathExpr(tokenpath, tokenstart, context);
if mend == 0, return; end
tokenpathlen = length(tokenpath);
while mend + 1 <= tokenpathlen & strcmp(tokenpath(mend+1).value, '|')
  tokenstart = mend+2;
  [mend2, mobj2] = xpparsePathExpr(tokenpath, tokenstart, context);
  if mend2 == 0, return; end
  if ~strcmp(mobj.type, 'node-set')
    errmsg = ['XPath UnionExpr requires "' tokenpath(tokenstart:mend).value '" to return a node-set'];
    mend = 0;
    return
  end
  if ~strcmp(mobj2.type, 'node-set')
    errmsg = ['XPath UnionExpr requires "' tokenpath(mend+2:mend).value '" to return a node-set'];
    mend = 0;
    return
  end
  mend = mend2;
  mobj.value(end+1:end+length(mobj2.value)) = mobj2.value;
end
mobj.value = uniqueXPathNodes(mobj.value);
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparsePathExpr(tokenpath, tokenstart, context)
%[19]    PathExpr    ::=    LocationPath
%   | FilterExpr
%   | FilterExpr '/' RelativeLocationPath
%   | FilterExpr '//' RelativeLocationPath
%[1]    LocationPath    ::=    RelativeLocationPath
%   | AbsoluteLocationPath
%[2]    AbsoluteLocationPath    ::=    '/' RelativeLocationPath?
%   | AbbreviatedAbsoluteLocationPath
%[10]    AbbreviatedAbsoluteLocationPath    ::=    '//' RelativeLocationPath

% enumerating all the possibilities covered by this function:
% FilterExpr                                 [PathExpr]
% FilterExpr '/'  RelativeLocationPath       [PathExpr]
% FilterExpr '//' RelativeLocationPath       [PathExpr]
%            '/'                             [AbsoluteLocationPath]
%            '/'  RelativeLocationPath       [AbsoluteLocationPath]
%            '//' RelativeLocationPath       [AbbreviatedAbsoluteLocationPath]
%                 RelativeLocationPath       [LocationPath]
% the '//' cases should have already been expanded

%disp(['PathExpr: ' tokenpath(tokenstart:end).value]);
global errmsg;
% set up the base case
contextnodes = context.node;
% Check for FilterExpr
foundfilter = 0;
foundslash = 0;
[mend, mobj] = xpparseFilterExpr(tokenpath, tokenstart, context);
if mend == 0, mobj = []; end
if ~isempty(mobj)
  tokenstart = mend + 1;
  % assume FilterExpr returns node-set
  contextnodes = mobj.value;
  foundfilter = 1;
end
% see if there's a '/' or '//'
tokenpathlen = length(tokenpath);
if tokenstart <= tokenpathlen & strcmp(tokenpath(tokenstart).value, '/')
  foundslash = 1;
  if ~foundfilter
    % AbsoluteLocationPath
    docnode = [];
    if strcmp(context.node.xptype, 'namespace')
      docnode = context.node.data.domparent.getOwnerDocument;
    elseif strcmp(context.node.xptype, 'root')
      docnode = context.node.data.domnode;
    else
      docnode = context.node.data.domnode.getOwnerDocument;
    end
    contextnodes = struct('xptype', 'root', 'data', struct('domnode', docnode));
    % just in case there is no following relative path
    mobj.type = 'node-set';
    mobj.value = contextnodes;
    mend = tokenstart;
  end
  tokenstart = tokenstart + 1; % go past '/'
elseif tokenstart <= tokenpathlen & strcmp(tokenpath(tokenstart).value, '//')
  % this should never happen -- should have been expanded
  errmsg = 'Internal error -- XPath lexical parser didn''t expand "//"';
  mend = 0;
  return
end
mobj.value = struct('xptype', {}, 'data', {});
parsedrlp = 1;
if length(contextnodes) == 0
  % no context nodes, parse but throw out result
  [mend2, mobj2] = xpparseRelativeLocationPath(tokenpath, tokenstart, context);
  mend = mend2;
  if mend2 == 0
    parsedrlp = 0;
  end
else
  % we can now modify context -- we've saved all the nodes we need
  for contextnode = contextnodes
    context.node = contextnode;
    [mend2, mobj2] = xpparseRelativeLocationPath(tokenpath, tokenstart, context);
    if mend2 == 0
      parsedrlp = 0;
      break
    end
    % XXX assume mobj2 is a node-set?
    mobj.value(end+1:end+length(mobj2.value)) = mobj2.value;
    mend = mend2;
  end
  mobj.value = uniqueXPathNodes(mobj.value);
end
if ~parsedrlp
  % didn't parse RelativeLocationPath -- OK if bare FilterExpr xor '/'
  if (foundfilter & ~foundslash) | (~foundfilter & foundslash)
    % we're done
    return
  end
  errmsg = ['XPath  requires "' tokenpath(1:tokenstart-1).value '" to be followed by a RelativeLocationPath'];
  mend = 0;
  return
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseRelativeLocationPath(tokenpath, tokenstart, context)
%[3]    RelativeLocationPath    ::=    Step
%   | RelativeLocationPath '/' Step
%   | AbbreviatedRelativeLocationPath
%[11]    AbbreviatedRelativeLocationPath    ::=    RelativeLocationPath '//' Step

% another way of defining the possibilities (?):
% Step
% Step '/' RelativeLocationPath
% Step '//' Step                    [should already be expanded]

%disp(['RelativeLocationPath: ' tokenpath(tokenstart:end).value]);
global errmsg;
[mend, mobj] = xpparseStep(tokenpath, tokenstart, context);
if mend == 0, return; end
tokenstart = mend + 1;
tokenpathlen = length(tokenpath);
if tokenstart + 1 <= tokenpathlen
  % assume Step returns node-set
  contextnodes = mobj.value;
  if strcmp(tokenpath(tokenstart).value, '/')
    tokenstart = tokenstart + 1;
    mobj.value = struct('xptype', {}, 'data', {});
    if length(contextnodes) == 0
      % no context nodes, parse but throw out result
      [mend2, mobj2] = xpparseRelativeLocationPath(tokenpath, tokenstart, context);
      mend = mend2;
    else
      for contextnode = contextnodes
        context.node = contextnode;
        [mend2, mobj2] = xpparseRelativeLocationPath(tokenpath, tokenstart, context);
        if mend2 == 0, mend = 0; return; end % bad RelativeLocationPath
        mobj.value(end+1:end+length(mobj2.value)) = mobj2.value;
        mend = mend2;
      end
      mobj.value = uniqueXPathNodes(mobj.value);
    end
    return
  elseif strcmp(tokenpath(tokenstart).value, '//')
    % this should never happen -- should have been expanded
    errmsg = 'Internal error -- XPath lexical parser didn''t expand "//"';
    mend = 0;
    return
  end
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseStep(tokenpath, tokenstart, context)
%[4]   	Step	   ::=   	AxisSpecifier NodeTest Predicate*	
%   | AbbreviatedStep	
%[5]   	AxisSpecifier	   ::=   	AxisName '::'	
%   | AbbreviatedAxisSpecifier 	
%[12]    AbbreviatedStep    ::=    '.'
%   | '..'
%[13]    AbbreviatedAxisSpecifier    ::=    '@'?
%[7]   	NodeTest	   ::=   	NameTest	
%			| NodeType '(' ')'	
%			| 'processing-instruction' '(' Literal ')'	
%[37]   NameTest	   ::=   	'*'	
%			| NCName ':' '*'	
%			| QName

% enumerating the possibilities:
% '.'                                 [should have already been expanded]
% '..'                                [should have already been expanded]
% AxisName '::' NodeTest Predicate*
% '@'           NodeTest Predicate*   [should have already been expanded]
%               NodeTest Predicate*

%disp(['Step: ' tokenpath(tokenstart:end).value]);
global errmsg;
mobj = [];
mobj.type = 'node-set';
mobj.value = struct('xptype', {}, 'data', {});
tokenpathlen = length(tokenpath);
curtoken = tokenpath(tokenstart);
if strcmp(curtoken.value, '.')
  % this should never happen -- should have been expanded
  errmsg = 'Internal error -- XPath lexical parser didn''t expand "."';
  mend = 0;
  return
end
if strcmp(curtoken.value, '..')
  % this should never happen -- should have been expanded
  errmsg = 'Internal error -- XPath lexical parser didn''t expand ".."';
  mend = 0;
  return
end
if strcmp(curtoken.value, '@')
  % this should never happen -- should have been expanded
  errmsg = 'Internal error -- XPath lexical parser didn''t expand "@"';
  mend = 0;
  return
end
axisname = 'child'; % default axis
if strcmp(curtoken.gtype, 'AxisName')
  if tokenstart + 1 > tokenpathlen | ...
        ~strcmp(tokenpath(tokenstart + 1).value, '::')
    errmsg = ['XPath AxisName "' curtoken.value '" must be followed by "::"'];
    mend = 0;
    return
  end
  axisname = curtoken.value;
  tokenstart = tokenstart + 2;
end
if tokenstart > tokenpathlen
  errmsg = ['XPath NodeTest must follow ' [tokenpath.value]];
  mend = 0;
  return
end

% construct new context node list based on axis
contextnodes = getNodesOnAxis(context.node, axisname);

% do NodeTest
curtoken = tokenpath(tokenstart);
if strcmp(curtoken.value, 'processing-instruction')
  if tokenstart + 3 > tokenpathlen | ...
        ~strcmp(tokenpath(tokenstart+1).value, '(') | ...
        ~strcmp(tokenpath(tokenstart+2).gtype, 'Literal') | ...
        ~strcmp(tokenpath(tokenstart+3).value, ')')
    errmsg = ['Error parsing XPath NodeTest processing instruction ' tokenpath(tokenstart:end).value];
    error(errmsg);
  end
  piname = tokenpath(tokenstart+2).value(2:end-1); % get rid of quotes
  for contextnode = contextnodes
    if strcmp(contextnode.xptype, 'processing-instruction') & ...
          strcmp(cindex(cell(contextnode.data.domnode.getNodeName), piname),1)
      mobj.value(end+1) = contextnode;
    end
  end
  mend = tokenstart + 3;
elseif strcmp(curtoken.gtype, 'NodeType')
  if tokenstart + 2 > tokenpathlen | ...
        ~strcmp(tokenpath(tokenstart+1).value, '(') | ...
        ~strcmp(tokenpath(tokenstart+2).value, ')')
    errmsg = ['Error parsing XPath NodeTest node type ' tokenpath(tokenstart:end).value];
    mend = 0;
    return
  end
  xptype = tokenpath(tokenstart).value;
  for contextnode = contextnodes
    if strcmp(contextnode.xptype, xptype)
      mobj.value(end+1) = contextnode;
    end
  end
  mend = tokenstart + 2;
else
  % do NameTest (curtoken.gtype better be 'NameTest'!)
  matchname = tokenpath(tokenstart).value;
  wildcardname = 0;
  if strcmp(matchname, '*'), wildcardname = 1; end
  matchuri = [];
  comps = splitstr(matchname, ':');
  if length(comps) > 2
    errmsg = ['QName ', matchname, ' has too many colons'];
    mend = 0;
    return;
  end
  if length(comps) > 1
    matchprefix = comps{1};
    if isfield(context.nsdecls, matchprefix)
      matchname = comps{2};
      matchuri = getfield(context.nsdecls, matchprefix);
    else
      errmsg = ['Prefix ', matchprefix, ' does not exist'];
      mend = 0;
      return
    end
  end
  if strcmp(axisname, 'namespace')
    for contextnode = contextnodes
      if ~strcmp(contextnode.xptype, 'namespace'), break; end
      if wildcardname
        mobj.value(end+1) = contextnode;
      end
      prefix = contextnode.data.prefix; % prefix
      if strcmp(matchname, prefix)
        mobj.value(end+1) = contextnode;
      end
    end
  else
    principalnodetype = 'element';
    if strcmp(axisname, 'attribute')
      principalnodetype = 'attribute';
    end
    for contextnode = contextnodes
      if ~strcmp(contextnode.xptype, principalnodetype), continue; end
      if wildcardname & isempty(matchuri)
        mobj.value(end+1) = contextnode;
      end
      localname = contextnode.data.localname;
      prefix = contextnode.data.prefix;
      nsuri = contextnode.data.nsuri;
      if (~isempty(nsuri) | ~isempty(matchuri)) & ~strcmp(nsuri, matchuri)
        continue;
      end
      % URIs match
      if ~wildcardname & ~strcmp(matchname, localname), continue; end
      % names match
      mobj.value(end+1) = contextnode;
    end
  end
  mend = tokenstart;
end

% now filter by Predicates (if any)
tokenstart = mend + 1;
mend2 = 1;
while mend2 ~= 0 & tokenstart <= tokenpathlen
  contextnodes = mobj.value;
  mobj.value = struct('xptype', {}, 'data', {});
  context.size = length(contextnodes);
  if context.size == 0
    % no context nodes, parse predicate, but throw out result
    [mend2, mobj2] = xpparsePredicate(tokenpath, tokenstart, context);
    if mend2 == 0
      mobj.value = contextnodes;
      break
    end
    mend = mend2;
  else
    for nodenum = 1:context.size
      context.node = contextnodes(nodenum);
      context.position = nodenum;
      [mend2, mobj2] = xpparsePredicate(tokenpath, tokenstart, context);
      if mend2 == 0
        mobj.value = contextnodes;
        break
      end
      mend = mend2;
      mobj.value(end+1:end+length(mobj2.value)) = mobj2.value;
    end
  end
  mobj.value = uniqueXPathNodes(mobj.value);
  tokenstart = mend + 1;
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseFilterExpr(tokenpath, tokenstart, context)
%[20]    FilterExpr    ::=    PrimaryExpr
%   | FilterExpr Predicate
%disp(['Filter: ' tokenpath(tokenstart:end).value]);
global errmsg;
tokenpathlen = length(tokenpath);
try [mend, mobj] = xpparsePrimaryExpr(tokenpath, tokenstart, context);
catch mend = 0; mobj= [];
end
if mend == 0, return; end % need at least one PrimaryExpr
if ~strcmp(mobj.type, 'node-set')
  errmsg = ['XPath FilterExpr expects PrimaryExpr ' tokenpath(tokenstart:mend) ' to return node-set'];
  mend = 0;
  return
end
tokenstart = mend + 1;
mend2 = mend;
contextnodes = [];
while mend2 ~= 0 & tokenstart <= tokenpathlen
  contextnodes = mobj.value;
  mobj.value = struct('xptype', {}, 'data', {});
  if length(contextnodes) == 0
    % no context nodes, parse but throw out result
    [mend2, mobj2] = xpparsePrimaryExpr(tokenpath, tokenstart, context);
    if mend2 ~= 0
      mend = mend2;
    end
  else
    for contextnode = contextnodes
      context.node = contextnode;
      [mend2, mobj2] = xpparsePrimaryExpr(tokenpath, tokenstart, context);
      if mend2 == 0, break; end
      if ~strcmp(mobj2.type, 'node-set')
        errmsg = ['XPath FilterExpr expects PrimaryExpr ' tokenpath(tokenstart:mend) ' to return node-set'];
        mend = 0;
        return
      end
      mend = mend2;
      mobj.value(end+1:end+length(mobj2.value)) = mobj2.value;
    end
    mobj.value = uniqueXPathNodes(mobj.value);
  end
  tokenstart = mend + 1;
end
% now apply Predicate
mobj.value = struct('xptype', {}, 'data', {});
if length(contextnodes) == 0
  % no context nodes, parse but throw out result
  [mend2, mobj2] = xpparsePredicate(tokenpath, tokenstart, context);
  if mend2 == 0
    errmsg = ['XPath FilterExpr expects a Predicate: ' tokenpath(1:tokenstart-1).value ' <here> ' tokenpath(tokenstart:end).value];
    mend = 0;
    return
  end
else
  for contextnode = contextnodes
    context.node = contextnode;
    [mend2, mobj2] = xpparsePredicate(tokenpath, tokenstart, context);
    if mend2 == 0
      errmsg = ['XPath FilterExpr expects a Predicate: ' tokenpath(1:tokenstart-1).value ' <here> ' tokenpath(tokenstart:end).value];
      mend = 0;
      return
    end
    mend = mend2;
    % assume Predicate returns boolean
    if mobj2.value
      mobj.value(end+1) = contextnode;
    end
  end
  mobj.value = uniqueXPathNodes(mobj.value);
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparsePrimaryExpr(tokenpath, tokenstart, context)
%[15]    PrimaryExpr    ::=    VariableReference
%   | '(' Expr ')'
%   | Literal
%   | Number
%   | FunctionCall
%disp(['PrimaryExpr: ' tokenpath(tokenstart:end).value]);
global errmsg;
mobj = [];
tokenpathlen = length(tokenpath);
if strcmp(tokenpath(tokenstart).value, '(')
  if tokenstart + 1 > tokenpathlen, mend = 0; return; end
  try [mend, mobj] = xpparseExpr(tokenpath, tokenstart + 1, context);
  catch mend = 0; mobj= [];
  end
  if mend == 0, return; end
  if mend + 1 > tokenpathlen | ~strcmp(tokenpath(mend+1).value, ')')
    mend = 0;
    return
  end
  mend = mend + 1;
  return
end
[mend, mobj] = xpparseFunctionCall(tokenpath, tokenstart, context)
if mend ~= 0, return; end
if strcmp(tokenpath(tokenstart).gtype, 'VariableReference')
  mend = tokenstart;
  varname = tokenpath(tokenstart).gtype(2:end);
  if ~isfield(context.vars, varname)
    errmsg = ['Undefined variable "' varname '": ' tokenpath(1:tokenstart-1).value ' <here> ' tokenpath(tokenstart:end).value];
    mend = 0;
    return
  end
  mobj = getfield(context.vars, varname);
  return
end
if strcmp(tokenpath(tokenstart).gtype, 'Literal')
  mend = tokenstart;
  mobj.type = 'string';
  mobj.value = tokenpath(tokenstart).value(2:end-1); % get rid of quotes;
  return
end
if strcmp(tokenpath(tokenstart).gtype, 'Number')
  mend = tokenstart;
  mobj.type = 'number';
  mobj.value = str2num(tokenpath(tokenstart).value);
  return
end
mend = 0;
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparsePredicate(tokenpath, tokenstart, context)
%[8]    Predicate    ::=    '[' PredicateExpr ']'
%disp(['Predicate: ' tokenpath(tokenstart:end).value]);
global errmsg;
mobj = [];
if ~strcmp(tokenpath(tokenstart).value, '[')
  mend = 0;
  return
end
tokenpathlen = length(tokenpath);
if tokenstart + 1 > tokenpathlen
  errmsg = ['XPath expects PredicateExpr: ' tokenpath(1:tokenstart).value ' <here> ' tokenpath(tokenstart+1:end).value];
  mend = 0;
  return
end
[mend, mobj] = xpparsePredicateExpr(tokenpath, tokenstart + 1, context);
if mend == 0
  errmsg = ['XPath error parsing PredicateExpr: ' tokenpath(1:tokenstart).value ' <here> ' tokenpath(tokenstart+1:end).value];
  mend = 0;
  return
end
if mend + 1 > tokenpathlen | ~strcmp(tokenpath(mend+1).value, ']')
  errmsg = ['XPath expects "]": ' tokenpath(1:mend).value ' <here> ' tokenpath(mend+1:end).value];
  mend = 0;
  return
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparsePredicateExpr(tokenpath, tokenstart, context)
%[9]    PredicateExpr    ::=    Expr
%disp(['PredicateExpr: ' tokenpath(tokenstart:end).value]);
[mend, mobj] = xpparseExpr(tokenpath, tokenstart, context);
if strcmp(mobj.type, 'number')
  mobj.type = 'boolean';
  if context.position == mobj.value
    mobj.value = 1;
  else
    mobj.value = 0;
  end
else
  mobj = xpfunc_boolean(mobj, context);
end
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mend, mobj]=xpparseFunctionCall(tokenpath, tokenstart, context)
%[16]    FunctionCall    ::=    FunctionName '(' ( Argument ( ',' Argument )* )? ')'
%[17]    Argument    ::=    Expr
%disp(['FunctionCall: ' tokenpath(tokenstart:end).value]);
global errmsg;
tokenpathlen = length(tokenpath);
if ~strcmp(tokenpath(tokenstart).gtype, 'FunctionName')
  errmsg = ['FunctionName expected: ' tokenpath(1:tokenstart-1).value ' <here> ' tokenpath(tokenstart:end).value];
  mend = 0;
  return
end
fname = tokenpath(tokenstart).value;
if tokenstart + 1 > tokenpathlen | ~strcmp(tokenpath(tokenstart+1).value, '(')
  errmsg = ['"(" expected after FunctionName: ' tokenpath(1:tokenstart).value ' <here> ' tokenpath(tokenstart+1:end).value];
  mend = 0;
  return
end
if tokenstart + 2 > tokenpathlen
  errmsg = ['XPath FunctionCall expects arguments or ending paren: ' tokenpath(1:tokenstart+1).value ' <here> ' tokenpath(tokenstart+2:end).value];
  mend = 0;
  return
end
mend = tokenstart + 2;
tokenstart = mend;
mend2 = mend;
arguments = [];
while mend2 ~= 0 & tokenstart <= tokenpathlen
  if strcmp(tokenpath(tokenstart).value, ')')
    % end of argument list
    mend = tokenstart;
    break
  end
  [mend2, mobj2] = xpparseExpr(tokenpath, tokenstart, context);
  if mend2 == 0
    errmsg = ['XPath FunctionCall expects Expr: ' tokenpath(1:tokenstart-1).value ' <here> ' tokenpath(tokenstart:end).value];
    mend = 0;
    return
    break;
  end
  mend = mend2;
  arguments(end+1) = mobj2;
  tokenstart = mend + 1;
end
% call the function
mobj = feval(['xpfunc_' fname], arguments(:), context);
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ret=xpfunc_boolean(mobj, context)
ret = [];
ret.type = 'boolean';
switch mobj.type
 case 'boolean'
  ret = mobj;
 case 'number'
  if any(mobj.value == [0 -0 NaN])
    ret.value = false;
  else
    ret.value = true;
  end
 case {'node-set', 'string'}
  ret.value = ~isempty(mobj.value);
 otherwise
  errmsg = ['Can''t convert XPath object of type ' mobj.type ' to boolean'];
  error(errmsg);
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ret=xpfunc_string(mobj, context)
if isempty(mobj)
  mobj = struct('type', {'node-set'}, 'value', {context.node});
end
ret = [];
ret.type = 'string';
if strcmp(mobj.type, 'node-set')
  if length(mobj.value) == 0
    ret.value = '';
    return
  end
  node = mobj.value(1);
  switch node.xptype
   case {'root', 'element'}
    strobj = java.lang.String;
    % depth-first recursion
    queue = [node.data.domnode];
    while length(queue) > 0
      curdomnode = queue(end);
      queue(end) = [];
      domtype = curdomnode.getNodeType;
      if domtype == 3 | domtype == 7 % TEXT or CDATA
        strobj.concat(curdomnode.getNodeValue);
      elseif domtype == 1 % ELEMENT
        childnodelist = curdomnode.getChildNodes;
        childlistlen = childnodelist.getLength;
        for childnum=childlistlen-1:-1:0
          curdomchild = childnodelist.item(childnum);
          queue(end+1) = curdomchild;
        end
      end
    end
    ret.value = cindex(cell(strobj),1); % quick char conv
   case 'namespace'
    ret.value = node.data.uri;
   otherwise
    ret.value = cindex(cell(node.getNodeValue),1); % quick char conv
  end
  return
end
switch mobj.type
 case 'string'
  ret = mobj;
 case 'number'
  switch mobj.value
   case NaN, ret.value = 'NaN';
   case {0, -0}, ret.value = '0';
   case {Inf, -Inf}, ret.value = 'Infinity';
   otherwise
    ret.value = num2str(mobj.value, '%.100f');
    % get rid of excess trailing zeros
    dots = (ret.value == '.')
    if ~isempty(dots)
      nonzeros = find(ret.value ~= '0');
      if nonzeros(end) > dots(1)
        ret.value(nonzeros(end)+1:end) = [];
      end
    end
  end
 case 'boolean'
  if mobj.value, ret.value = 'true';
  else ret.value = 'false';
  end
 otherwise
  errmsg = ['Can''t convert XPath object of type ' mobj.type ' to string'];
  error(errmsg);
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ret=xpfunc_number(mobj, context)
ret = [];
ret.type = 'number';
switch mobj.type
 case 'number'
  ret = mobj;
 case 'string'
  ret.value = str2num(mobj.value);
  if isempty(ret.value)
    ret.value = NaN;
  end
 case 'boolean'
  if mobj.value, ret.value = 1;
  else ret.value = 0;
  end
 case 'node-set'
  ret = xpfunc_number(xpfunc_string(mobj, context), context);
  ret.value = ~isempty(mobj.value);
 otherwise
  errmsg = ['Can''t convert XPath object of type ' mobj.type ' to number'];
  error(errmsg);
end
return




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function outpaths=convertXPaths(inpaths)

operatornametokens = strvcat('and', 'or', 'mod', 'div');
opprectokens = strvcat('@', '::', '(', '[', ',');

outpaths = {};

numpaths = length(inpaths);
for pathnum = 1:numpaths
  inpath = inpaths{pathnum};
  % tokenize the path
  tokens = struct('gtype', {}, 'value', {});
  inpath = trim(inpath);
  while length(inpath) > 0
    while 1
      % ExprToken ::=
      %   '(' | ')' | '[' | ']' | '.' | '..' | '@' | ',' | '::'
      %   | NameTest
      %   | NodeType
      %   | Operator
      %   | FunctionName
      %   | AxisName
      %   | Literal
      %   | Number
      %   | VariableReference
      newtoken = [];
      matchlen = 0;
      prefixmat = strvcat('(', ')', '[', ']', ',', '::');
      [matchlen, match] = matchMatrixPrefixes(inpath, prefixmat);
      if ~isempty(match)
        newtoken.gtype = 'ExprToken';
        newtoken.value = match;
        break
      end
      if strncmp(inpath, '@', 1)
        matchlen = 1;
        newtoken(1).gtype = 'AxisName';
        newtoken(1).value = 'attribute';
        newtoken(2).gtype = 'Operator';
        newtoken(2).value = '::';
        break
      end
      if strncmp(inpath, '.', 1)
        matchlen = 1;
        newtoken(1).gtype = 'AxisName';
        newtoken(1).value = 'self';
        newtoken(2).gtype = 'Operator';
        newtoken(2).value = '::';
        newtoken(3).gtype = 'NodeType';
        newtoken(3).value = 'node';
        newtoken(4).gtype = 'ExprToken';
        newtoken(4).value = '(';
        newtoken(5).gtype = 'ExprToken';
        newtoken(5).value = ')';
        break
      end
      if strncmp(inpath, '..', 2)
        matchlen = 2;
        newtoken(1).gtype = 'AxisName';
        newtoken(1).value = 'parent';
        newtoken(2).gtype = 'Operator';
        newtoken(2).value = '::';
        newtoken(3).gtype = 'NodeType';
        newtoken(3).value = 'node';
        newtoken(4).gtype = 'ExprToken';
        newtoken(4).value = '(';
        newtoken(5).gtype = 'ExprToken';
        newtoken(5).value = ')';
        break
      end
      
      % Order is important to disambiguate NameTest from:
      %  Operator (e.g. '*')
      %  NodeType (e.g. 'element')
      %  FunctionName (e.g. 'substring-before')
      %  AxisName (e.g. 'descendant-or-self')
      % Rules come from Sec. 3.7 in XPath1 specification

      % Operator
      matchlen = xplexOperator(inpath);
      if matchlen
        % '*', 'and', 'or', 'mod', 'div' should not be considered
        % Operators if they are at the begnning of an XPath or if they
        % follow another Operator or the tokens '@', '::', '(', '[', or ','
        newtoken.gtype = 'Operator';
        newtoken.value = inpath(1:matchlen);
        if (~strcmp(newtoken.value, '*') & ...
            ~matchMatrixPrefixes(newtoken.value, operatornametokens)) | ...
           (length(tokens) > 0 & ...
            (strcmp(tokens(end).gtype, 'Operator') | ...
             matchMatrixPrefixes(tokens(end).value, opprectokens)))
          % either this is not '*', 'and', 'or', 'mod', or 'div', or
          % otherwise this is a proper place for an operator so accept it
          if strcmp(newtoken.value, '//')
            % expand this
            newtokenlist = {...
                'Operator',  '/',...
                'AxisName',  'descendant-or-self',...
                'Operator',  '::',...
                'NodeType',  'node',...
                'ExprToken', '(',...
                'ExprToken', ')',...
                'Operator',  '/' };
            newtoken = struct('gtype', newtokenlist(1:2:end), 'value', newtokenlist(2:2:end));
          end
          break
        end
        % not a valid Operator location, fall through to next test
      end

      % NodeType
      matchlen = xplexNodeType(inpath);
      if matchlen
        % NodeType must be followed by '(' (intervening whitespace OK)
        if strncmp(trim(inpath(matchlen+1:end)), '(', 1)
          % accept it
          newtoken.gtype = 'NodeType';
          newtoken.value = inpath(1:matchlen);
          break
        end
        % NodeType not followed by '(', fall through to next test
      end

      % FunctionName
      matchlen = xplexFunctionName(inpath);
      if matchlen
        % FunctionName must be followed by '(' (intervening whitespace OK)
        if strncmp(trim(inpath(matchlen+1:end)), '(', 1)
          % accept it
          newtoken.gtype = 'FunctionName';
          newtoken.value = inpath(1:matchlen);
          break
        end
        % FunctionName not followed by '(', fall through to next test
      end

      % AxisName
      matchlen = xplexAxisName(inpath);
      if matchlen
        % AxisName must be followed by '::' (intervening whitespace OK)
        if strncmp(trim(inpath(matchlen+1:end)), '::', 2)
          % accept it
          newtoken.gtype = 'AxisName';
          newtoken.value = inpath(1:matchlen);
          break
        end
        % AxisName not followed by '::', fall through to next test
      end

      % NameTest
      matchlen = xplexNameTest(inpath);
      if matchlen
        newtoken.gtype = 'NameTest';
        newtoken.value = inpath(1:matchlen);
        break
      end

      % Literal
      matchlen = xplexLiteral(inpath);
      if matchlen
        newtoken.gtype = 'Literal';
        newtoken.value = inpath(1:matchlen);
        break
      end

      % Number
      matchlen = xplexNumber(inpath);
      if matchlen
        newtoken.gtype = 'Number';
        newtoken.value = inpath(1:matchlen);
        break
      end

      % VariableReference
      matchlen = xplexVariableReference(inpath);
      if matchlen
        newtoken.gtype = 'VariableReference';
        newtoken.value = inpath(1:matchlen);
        break
      end

      errmsg = ['Error in XPath string starting at "' inpath '"'];
      error(errmsg);
    end

    if isempty(newtoken), errmsg = 'Couldn''t match XPath ExprToken'; error(errmsg); end
    tokens(end+1:end+length(newtoken)) = newtoken;
    inpath = trim(inpath(matchlen+1:end));
  end
  outpaths{end+1} = tokens;
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchlen=xplexNameTest(inpath)
% NameTest ::=
%   '*'
%   | NCName ':' '*'
%   | QName
matchlen = 0;
if inpath(1) == '*'
  matchlen = 1;
  return
end
matchlen = xpmatchNCName(inpath);
if matchlen
  % Check if the NCName is followed by a colon,
  % and then by '*' or another NCName
  inpathlen = length(inpath);
  if inpathlen >= matchlen + 2 & inpath(matchlen+1) == ':'
    matchlen = matchlen + 1;
    if inpath(matchlen+2) == '*'
      matchlen = matchlen + 1;
      return
    end
    ncmatchlen = xpmatchNCName(inpath(matchlen+1:end));
    if ncmatchlen
      matchlen = matchlen + ncmatchlen;
      return
    else
      matchlen = 0;
    end
  end
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchlen=xplexNodeType(inpath)
% NodeType ::= 'comment'
%   | 'text'
%   | 'processing-instruction'
%   | 'node'
matchlen = 0;
prefixmat = strvcat('comment', 'text', 'processing-instruction', 'node');
matchlen = matchMatrixPrefixes(inpath, prefixmat);
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchlen=xplexOperator(inpath)
% Operator ::= OperatorName
%   | MultiplyOperator
%   | '/' | '//' | '|' | '+' | '-' | '=' | '!=' | '<' | '<=' | '>' | '>='
% OperatorName ::= 'and' | 'or' | 'mod' | 'div'
% MultiplyOperator ::= '*'
matchlen = 0;
prefixmat = strvcat('and', 'or', 'mod', 'div', '*', '//', '/', '|', '+', '-', '=', '!=', '<=', '<', '>=', '>'); % order is important!
matchlen = matchMatrixPrefixes(inpath, prefixmat);
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchlen=xplexFunctionName(inpath)
% FunctionName ::= QName - NodeType
%
% we assume the test for NodeType has already failed
% (otherwise, we'd have to do the test twice)
matchlen = xpmatchQName(inpath);
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchlen=xplexAxisName(inpath)
% AxisName ::= 'ancestor'
%   | 'ancestor-or-self'
%   | 'attribute'
%   | 'child'
%   | 'descendant'
%   | 'descendant-or-self'
%   | 'following'
%   | 'following-sibling'
%   | 'namespace'
%   | 'parent'
%   | 'preceding'
%   | 'preceding-sibling'
%   | 'self'
matchlen = 0;
prefixmat = strvcat('ancestor', 'ancestor-or-self', 'attribute', 'child', 'descendant', 'descendant-or-self', 'following', 'following-sibling', 'namespace', 'parent', 'preceding', 'preceding-sibling', 'self');
matchlen = matchMatrixPrefixes(inpath, prefixmat);
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchlen=xplexLiteral(inpath)
% Literal ::= '"' [^"]* '"'
%   | "'" [^']* "'"
%
matchlen = 0;
if inpath(1) == '''' | inpath(1) == '"'
  inds = findstr(inpath, inpath(1));
  if (inds < 2)
    errmsg = ['Unterminated string in XPath expression "' inpath '"']; error(errmsg);
  end
  matchlen = inds(2);
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchlen=xplexNumber(inpath)
% Number ::= Digits ('.' Digits?)?
%   | '.' Digits
matchlen = 0;
founddot = 0;
while matchlen < length(inpath)
  c = inpath(matchlen+1);
  if any(c == '0123456789')
    matchlen = matchlen + 1;
    continue
  end
  if c == '.'
    if founddot
      break
    else
      founddot = 1;
      matchlen = matchlen + 1;
      continue
    end
  end
  break
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchlen=xplexVariableReference(inpath)
% VariableReference ::= '$' QName
matchlen = 0;
if inpath(1) == '$'
  matchlen = xpmatchQName(inpath(2:end)) + 1;
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchlen=xpmatchNCName(inpath)
% NCName ::= (Letter | '_') (NCNameChar)*
% NCNameChar ::= Letter | Digit | '.' | '-' | '_' | CombiningChar | Extender
%
% (we use a simplified NCName)
matchlen = 0;
inpathlen = length(inpath);
if inpathlen >= 2 & isletter(inpath(1)) | inpath(1) == '_'
  for ind=2:length(inpath)
    c = inpath(ind);
    if isletter(c), continue; end
    if any(c == '0123456789.-_'), continue; end
    ind = ind - 1;
    break
  end
  matchlen = ind;
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matchlen=xpmatchQName(inpath)
% QName ::= Prefix ':' LocalPart
% Prefix ::= NCName
% LocalPart ::= NCName
matchlen = 0;
ncmatchlen = xpmatchNCName(inpath);
if ~ncmatchlen, return; end
inpathlen = length(inpath);
if inpathlen < ncmatchlen + 2 | inpath(ncmatchlen+1) ~= ':', return; end
ncmatchlen2 = xpmatchNCName(inpath(ncmatchlen+2:end));
if ~ncmatchlen2, return; end
matchlen = ncmatchlen + 1 + ncmatchlen2;
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [matchlen,match]=matchMatrixPrefixes(str,prefixmat)
% inspired by strmatch
match = [];
[matm,matn] = size(prefixmat);
strlen = length(str);
null = char(0);
space = ' ';
usenull = 0;
if ~isempty(prefixmat) & any(prefixmat(:,end)==null), usenull = 1; end
if strlen > matn
  str = str(1:matn);
elseif strlen < matn
  if usenull
    str = [str null(ones(1,matn-strlen))];
  else
    str = [str space(ones(1,matn-strlen))];
  end
end
empties = (prefixmat == null | prefixmat == space);
strmat = str(ones(matm,1),:);
prefixmat(empties) = strmat(empties);
inds = find(~sum((prefixmat(:,1:matn) ~= str(ones(matm,1),:)),2));
if ~isempty(inds)
  match = deblank(prefixmat(inds(1),~empties(inds(1),:)));
end
matchlen = length(match);
return

% $Log: readxml.m,v $
% Revision 1.14  2005/02/22 20:18:24  michelich
% Use more robust version parsing code.
%
% Revision 1.13  2005/02/03 20:23:10  michelich
% M-Lint: Replace deprecated setstr with char.
%
% Revision 1.12  2005/02/03 16:58:35  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.11  2004/07/30 19:43:22  gadde
% Fix potential bug
%
% Revision 1.10  2004/07/19 21:07:52  gadde
% Fix some typos and make sure longer tokens are matched before shorter ones
% (i.e. '//' vs. '/').
%
% Revision 1.9  2004/05/06 14:46:50  gadde
% Replace all uses of strfind with findstr (strfind doesn't exist before
% Matlab 6.1).
%
% Revision 1.8  2004/04/16 17:25:55  gadde
% Don't iterate over raw cell arrays in for statements.
%
% Revision 1.7  2004/04/14 17:58:38  gadde
% Fix version check.
%
% Revision 1.6  2004/04/14 16:10:09  gadde
% Add log message.
%
