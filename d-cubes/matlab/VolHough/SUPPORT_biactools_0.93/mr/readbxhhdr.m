function hdr=readbxhhdr(bxhfile)
% READBXHHDR - Read BXH header information
%
%  hdr=readbxhhdr;   % Choose bxhfile using GUI.
%  hdr=readbxhhdr(bxhfile);
%
%    bxhfile   - filename of bxh header file
%    hdr       - Structure of header information.
%              - Modifies field BASE to contain fully qualified URI for
%                basefile.  This can be used to construct the paths for the
%                filenames in the data.
%
% See Also: READBXHDATA, READXML

% CVS ID and authorship of this code
% CVSId = '$Id: readbxhhdr.m,v 1.17 2005/04/21 16:38:43 gadde Exp $';
% CVSRevision = '$Revision: 1.17 $';
% CVSDate = '$Date: 2005/04/21 16:38:43 $';
% CVSRCSFile = '$RCSfile: readbxhhdr.m,v $';

error(nargchk(0,1,nargin)); 
if nargin == 0
  % If bxhfile not specified, ask user to chose one.
  [filename, pathname] = uigetfile({'*.bxh;*.xml','BIAC XML Header (*.bxh,*.xml)'; ...
      '*.*','All Files (*.*)'},'Chose an XML image header to open');
  
  % Return if user does not pick a file
  if isequal(filename,0)|isequal(pathname,0), hdr=[]; return; end
  
  % Construct the xml filename
  bxhfile=fullfile(pathname,filename);
  clear filename pathname;
end

% Check if file exists
if ~exist(bxhfile,'file'),
  emsg=sprintf('BXH file %s does not exist!',bxhfile);  error(emsg);
end

% --- Read BXH file ---
dellocalloc = 0;
locurl = bxhfile;
if ~isa(locurl, 'url')
  locurl = filename2url(locurl);
end
proto = get(locurl,'Scheme');
pathstr = get(locurl, 'Path');
localloc = [];
if strcmp('file', proto)
  localloc = pathstr;
  if strcmp(filesep, '\') & localloc(1) == '/'
    localloc = localloc(2:end);
  end
else
  dellocalloc = 1;
  [localloc,message]=loadlocation(bxhfile);
  if isempty(localloc), emsg=message; error(emsg); end
  if ~exist(localloc,'file'),
    emsg = sprintf('Loaded XML Header file %s does not exist!',localloc); error(emsg);
  end
end

try
  nsdecls = [];
  nsdecls.bxh = 'http://www.biac.duke.edu/bxh';
  nsdecls.xcede = 'http://nbirn.net/Resources/Users/Applications/xcede/';
  hdr=readxml(localloc,nsdecls,...
    '/bxh:bxh/bxh:datarec/@type','/bxh:bxh/bxh:datarec/@subtype',...
    '/bxh:bxh/bxh:datarec/bxh:dimension/@type','/bxh:bxh/@version', ...
    '/bxh/datarec/@type','/bxh/datarec/@subtype',...
    '/bxh/datarec/dimension/@type','/bxh/@version',...
    '/xcede:serieslevel/xcede:datarec/@type',...
    '/xcede:serieslevel/xcede:datarec/@subtype',...
    '/xcede:serieslevel/xcede:datarec/xcede:dimension/@type');
catch
  if dellocalloc
    delete(localloc); % Delete temporary file from loadlocation
  end
  emsg=lasterr; 
  if isempty(emsg); emsg='Unknown error reading BXH file!'; end
  error(emsg);
end
if dellocalloc
  delete(localloc); % Delete temporary file from loadlocation
end

% --- Check the format of the XML file ---
if isfield(hdr, 'serieslevel')
  % convert from XCEDE to BXH
  hdr = local_xcede2bxh(hdr);
end
% Now the header is expected to have a valid bxh structure
if ~isfield(hdr,'bxh')
  emsg=sprintf('Invalid BXH file (%s):  Root element is not bxh',bxhfile); error(emsg);
end
% There must be a bxh namesspace declaration (/bxh/@xmlns:bxh="http://www.biac.duke.edu/bxh")
try
  bxhNamespace=hdr.bxh{1}.NSDEFS.bxh;
catch
  emsg=sprintf('Invalid BXH file (%s):  Does not contain bxh namespace declaration!',bxhfile); error(emsg);
end
if ~strcmp(bxhNamespace,'http://www.biac.duke.edu/bxh'), 
  emsg=sprintf('Invalid BXH file (%s):  bxh namespace declaration is not http://www.biac.duke.edu/bxh !',bxhfile); error(emsg);
end
% There must be a version attribute (/bxh/@version)
try
  hdrVersion = hdr.bxh{1}.ATTRS.version.VALUE;
catch
  emsg=sprintf('Invalid BXH file (%s):  Version not specified',bxhfile); error(emsg);
end
% TODO: Check against list of valid versions???

% Construct a fully qualified URI for the bxhfile & store in header
% (readxml might have used temporary file when writing BASE)
% TODO: Make sure geturifromfile gives fully qualified URI!
hdr.BASE=toString(filename2url(bxhfile));

% --- Check header entries for required fields ---
for datarec_i=1:length(hdr.bxh{1}.datarec)
  % Every datarec must have a type
  if ~isfield(hdr.bxh{1}.datarec{datarec_i},'ATTRS') | ...
    ~isfield(hdr.bxh{1}.datarec{datarec_i}.ATTRS,'type')
    error(sprintf('Invalid BXH file (%s):  /bxh/datarec[%d]/ does not have a type',bxhfile,datarec_i));
  end
  
%  % TODO: Do we want to do this??? or just handle it in the code  
%   % datarec subtype is implicitly '0'
%   if ~isfield(hdr.bxh{1}.datarec{datarec_i}.ATTRS,'subtype')
%     hdr.bxh{1}.datarec{datarec_i}.ATTRS.subtype.VALUE='0';
%   end
  
  % Every datarec must have at least one dimension
  if ~isfield(hdr.bxh{1}.datarec{datarec_i},'dimension')
    error(sprintf('Invalid BXH file (%s):  /bxh/datarec[%d]/ does not have any dimensions!',bxhfile,datarec_i));
  end
  
  % Every datarec must specify byte order
  if ~isfield(hdr.bxh{1}.datarec{datarec_i},'byteorder')
    error(sprintf('Invalid BXH file (%s):  /bxh/datarec[%d]/ does not specify byteorder!',bxhfile,datarec_i));
  end

  % Every datarec must specify element type
  if ~isfield(hdr.bxh{1}.datarec{datarec_i},'elementtype')
    error(sprintf('Invalid BXH file (%s):  /bxh/datarec[%d]/ does not specify elementtype!',bxhfile,datarec_i));
  end
  
  % Check dimensions
  for dimension_i=1:length(hdr.bxh{1}.datarec{datarec_i}.dimension)
    % Every dimension must have a size
    if ~isfield(hdr.bxh{1}.datarec{datarec_i}.dimension{dimension_i},'size')
      error(sprintf('Invalid BXH file (%s):  /bxh/datarec[%d]/dimension[%d] does not have a size!',bxhfile,datarec_i,dimension_i));
    end
  end

end


function hdr=local_xcede2bxh(oldhdr);
% local_xcede2bxh - Convert XCEDE header to BXH
%    oldhdr    - XCEDE header in XML structure as returned by READXML
%    hdr       - Output BXH XML structure
%
hdr = [];
hdr.COMMENTS(1).VALUE = ' This is a BXH (BIAC XML Header) file. ';
hdr.bxh{1}.ATTRS.version.VALUE = '1.0';
hdr.bxh{1}.NAMESPACE = 'http://www.biac.duke.edu/bxh';
hdr.bxh{1}.NSDEFS.DEFAULT = 'http://www.biac.duke.edu/bxh';
hdr.bxh{1}.NSDEFS.bxh = 'http://www.biac.duke.edu/bxh';
if isfield(oldhdr.serieslevel{1}, 'datarec')
  hdr.bxh{1}.datarec = oldhdr.serieslevel{1}.datarec;
  for dind=1:length(hdr.bxh{1}.datarec)
    hdr.bxh{1}.datarec{dind}.CHILDRANK = 1;
    hdr.bxh{1}.datarec{dind} = rmfield(hdr.bxh{1}.datarec{dind}, 'rasorigin');
  end
end
hdr.bxh{1}.subject{1}.CHILDRANK = 3;
if isfield(oldhdr.serieslevel{1}, 'visit')
  if isfield(oldhdr.serieslevel{1}.visit{1}, 'subjectVar')
    if isfield(oldhdr.serieslevel{1}.visit{1}.subjectVar{1}, 'age')
      hdr.bxh{1}.subject{1}.age{1}.VALUE = oldhdr.serieslevel{1}.visit{1}.subjectVar{1}.age{1}.VALUE;
    end
  end
end
if isfield(oldhdr.serieslevel{1}, 'subject')
  if isfield(oldhdr.serieslevel{1}.subject{1}, 'name')
    hdr.bxh{1}.subject{1}.name = oldhdr.serieslevel{1}.subject{1}.name;
  end
  if isfield(oldhdr.serieslevel{1}.subject{1}, 'sex')
    if strcmp(oldhdr.serieslevel{1}.subject{1}.sex{1}.VALUE, 'male')
      hdr.bxh{1}.subject{1}.sex{1}.VALUE = 'M';
    elseif strcmp(oldhdr.serieslevel{1}.subject{1}.sex{1}.VALUE, 'female')
      hdr.bxh{1}.subject{1}.sex{1}.VALUE = 'F';
    else
      hdr.bxh{1}.subject{1}.sex{1}.VALUE = 'O';
    end
  end
end
hdr.bxh{1}.acquisitiondata{1}.CHILDRANK = 2;
if isfield(oldhdr.serieslevel{1}, 'scanner')
  if isfield(oldhdr.serieslevel{1}.scanner{1}, 'model')
    hdr.bxh{1}.acquisitiondata{1}.scanner = oldhdr.serieslevel{1}.scanner{1}.model;
  end
end
if isfield(oldhdr.serieslevel{1}, 'acqProtocol')
  if isfield(oldhdr.serieslevel{1}.acqProtocol{1}, 'name')
    name = oldhdr.serieslevel{1}.acqProtocol{1}.name{1}.VALUE;
    pind1 = strfind(name, '(');
    pind2 = strfind(name, ')');
    if length(pind1) > 0 & length(pind2) > 0
      hdr.bxh{1}.acquisitiondata{1}.psdname{1}.VALUE = name(1:pind1(1)-1);
      hdr.bxh{1}.acquisitiondata{1}.internalpsdname{1}.VALUE = name(pind1(1)+1:pind2(1)-1);
    else
      hdr.bxh{1}.acquisitiondata{1}.psdname{1}.VALUE = name;
    end
  end
  if isfield(oldhdr.serieslevel{1}.acqProtocol{1}, 'acqParam')
    for adddind=1:length(oldhdr.serieslevel{1}.acqProtocol{1}.acqParam)
      addd=oldhdr.serieslevel{1}.acqProtocol{1}.acqParam{adddind};
      if isfield(addd, 'ATTRS') & isfield(addd.ATTRS, 'name')
        name = addd.ATTRS.name.VALUE;
        if strmatch(name, {'examnumber','studyid','seriesnumber','runnumber','scanningsequence','sequencevariant','magneticfield','description','scandate','scantime','tr','te','operator','flipangle','prescribedslicespacing','frequencydirection','acquisitionmatrix','bandwidth','receivecoilname','transmitcoilname'})
          eval(['hdr.bxh{1}.acquisitiondata{1}.' name '{1}.VALUE = addd.VALUE;']);
          eval(['hdr.bxh{1}.acquisitiondata{1}.' name '{1}.CHILDRANK = adddind;']);
        end
      end
    end
  end
end
hdr.bxh{1}.history{1}.CHILDRANK = 4;
if isfield(oldhdr.serieslevel{1}, 'provenance')
  hdr.bxh{1}.history{1}.entry = {};
  for prov=oldhdr.serieslevel{1}.provenance
    prov = prov{1};
    if isfield(prov, 'processStep')
      for procstep=prov.processStep
        procstep = procstep{1};
        entry = [];
        if isfield(procstep, 'timeStamp')
          entry.date = procstep.timeStamp;
        end
        entry.description{1}.processStep{1} = procstep;
      end
    end
    hdr.bxh{1}.history{1}.entry{end+1} = entry;
  end
end
% convert all namespaces to BXH namespace
queue = { 'hdr.bxh{1}' };
while length(queue) > 0
  evalstr = queue{1};
  queue(1) = [];
  eval([evalstr '=setfield(' evalstr ', ''NAMESPACE'', ''http://www.biac.duke.edu/bxh'');']);
  fields = fieldnames(eval(evalstr));
  for field=fields
    field = field{1};
    if strmatch(field, {'ATTRS','NSDEFS','NAMESPACE','VALUE','VALUECHILDRANK','PINSTS','COMMENTS','BASE','CHILDRANK'})
      continue
    end
    numelems = length(eval([evalstr '.' field]));
    for elemnum=1:numelems
      queue{end+1} = [evalstr '.' field '{' num2str(elemnum) '}'];
    end
  end
end
return

      
% Modification History:
%
% $Log: readbxhhdr.m,v $
% Revision 1.17  2005/04/21 16:38:43  gadde
% Add support for XCEDE (from BIRN) files.
%
% Revision 1.16  2005/02/03 16:58:41  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.15  2004/05/05 17:13:25  gadde
% Don't call loadlocation unnecessarily.
%
% Revision 1.14  2004/04/14 16:11:37  gadde
% Send explicit namespace declarations to readxml for XPath context.
% Requires contemporary versions of readxml.c (1.36 or greater) or
% readxml.m (1.4 or greater).
%
% Revision 1.13  2003/10/22 15:54:38  gadde
% Make some CVS info accessible through variables
%
% Revision 1.12  2003/10/14 14:58:53  gadde
% Name change: geturlfromfile => filename2url
%
% Revision 1.11  2003/10/13 21:31:43  gadde
% AUTOGEN magic now in readxml.
%
% Revision 1.10  2003/09/22 18:11:16  gadde
% Make search for AUTOGEN more efficient.
% Will eventually move to readxml.c
%
% Revision 1.9  2003/09/22 17:38:35  gadde
% Make queue empty if popping last element.
%
% Revision 1.8  2003/09/09 15:03:21  gadde
% Remove AUTOGEN comments.
%
% Revision 1.7  2003/03/20 16:58:06  gadde
% Big commit:
%   * introduction of new URL class to replace java.net.URL
%   * old-style readmr() arguments supported
%   * many, many performance enhancements
%   * 'NOPROGRESSBAR' can now be last argument of readmrtest()
%   * readtsv() uses readmrtest()
%
% Revision 1.6  2003/01/09 20:50:39  gadde
% Fixed comment.
%
% Revision 1.5  2003/01/09 20:27:49  gadde
% readxml will now give a BASE field.  Use that instead of BXHFILE.
%
% Revision 1.4  2003/01/08 19:05:35  michelich
% Require bxh namespace declaration.
% Include no namespace version on XPaths which are being forced to be strings.
%
% Revision 1.3  2003/01/08 17:27:07  gadde
% New method for deleteonclose -- still doesn't work on Windows yet :(
%
% Revision 1.2  2002/12/18 15:43:27  michelich
% Added more header format checking.
% Force type, subtype, and version attributes to be strings.
%
% Revision 1.1  2002/12/10 15:48:32  michelich
% Initial CVS import.  Based on code from readbxhdata.m.
%
%
