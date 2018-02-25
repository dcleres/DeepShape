function data=readbxhdata(bxhref,recType,recSubType)
% READBXHDATA - Read data specified by BXH header file
%
%  data=readbxhdata;            % Choose bxhfile using GUI.
%  data=readbxhdata(bxhfile);   % Choose type & subtype using GUI.
%  data=readbxhdata(bxhheader); % Choose type & subtype using GUI.
%  data=readbxhdata(bxhfile,type,subtype);
%  data=readbxhdata(bxhheader,type,subtype);
%
%    bxhfile   - filename of bxh header file
%    bxhheader - Parsed bxh header (i.e. using readbxhhdr)
%    type      - Type of data record to read.
%                  If not specified or '', select using GUI.
%                  If type is not specifed and there is only one record,
%                  it will be used automatically. 
%    subtype   - Subtype of data record to read.  
%                  This specifies which of the records of the type
%                  specified to read.  If not specified or '', and there is
%                  only one record of the type specified, it will be read.
%                  Otherwise an error will occur.  If subtype not listed in
%                  bxh header, it is implicitly '0'
%    data      - N-D array of image data read
%
% Note: If type is only one record, 
%
% See Also: READBXHHDR, READXML, READMR
%

% TODO: Handle paths to files correctly!

% CVS ID and authorship of this code
% CVSId = '$Id: readbxhdata.m,v 1.35 2005/02/03 16:58:41 michelich Exp $';
% CVSRevision = '$Revision: 1.35 $';
% CVSDate = '$Date: 2005/02/03 16:58:41 $';
% CVSRCSFile = '$RCSfile: readbxhdata.m,v $';

emsg=''; % Initialize error message for catch
try
  error(nargchk(0,3,nargin));
  % Set defaults
  if nargin < 2, recType=''; end % Default to '' record (GUI prompt)
  if nargin < 3, recSubType=''; end % Default to subtype not specified.
  
  % Issue error if recSubType specified without specifying recType
  if nargin > 2 & isempty(recType),
    error('Cannot specify subtype without specifying type!');
  end
  
  if nargin == 0
    % If bxhfile not specified, ask user to chose one.
    [filename, pathname] = uigetfile({'*.bxh;*.xml','BIAC XML Header (*.bxh,*.xml)'; ...
        '*.*','All Files (*.*)'},'Chose an BXH header to open');
    
    % Return if user does not pick a file
    if isequal(filename,0)|isequal(pathname,0), data=[]; return; end
    
    % Construct the BXH header name
    bxhref=fullfile(pathname,filename);
    
    clear filename pathname;
  end
  
  % Handle bxhref input
  if ischar(bxhref)
    % bxhfile specified. Read it.
    bxhfile=bxhref;
    hdr=readbxhhdr(bxhfile);
  elseif isstruct(bxhref)
    % bxh header structure specified. Use it.
    hdr=bxhref;
    bxhfile='[argument]';  % Dummy string for error messages.

    % --- Check the format of the XML file ---
    % TODO: Add better error checking (perhaps a function?)
    if ~isfield(hdr,'bxh')
      emsg='Invalid parsed bxh header:  Root element is not bxh'; error(emsg);
    end
    % There must be a bxh namesspace declaration (/bxh/@xmlns:bxh="http://www.biac.duke.edu/bxh")
    try
      bxhNamespace=hdr.bxh{1}.NSDEFS.bxh;
    catch
      emsg='Invalid parsed bxh header:  Does not contain bxh namespace declaration!'; error(emsg);
    end
    if ~strcmp(bxhNamespace,'http://www.biac.duke.edu/bxh'), 
      emsg='Invalid parsed bxh header:  bxh namespace declaration is not http://www.biac.duke.edu/bxh !'; error(emsg);
    end
    % There must be a version attribute (/bxh/@version)
    try
      hdrVersion = hdr.bxh{1}.ATTRS.version.VALUE;
    catch
      emsg='Invalid bxh header:  Version not specified'; error(emsg);
    end
    % There must be a BASE field indicating the original fully qualified
    % path to bxh header file.
    if ~isfield(hdr,'BASE')
      emsg='Invalid parsed bxh header:  Please read file using readbxhhdr.'; error(emsg);
    end    
  else
    emsg=sprintf('First argument is neither a struct nor a string'); error(emsg);
  end
  
  % Version must be 1.0
  % TODO: Handle version checking better.  Perhaps move to readbxhhdr?
  if ~strcmp(hdr.bxh{1}.ATTRS.version.VALUE,'1.0') 
    emsg='Unknown header revision!'; error(emsg);
  end
  
  % If user did not specify record type, prompt for it:
  if isempty(recType)
    out=local_gensummaries(hdr);
    if length(out) > 1
      % More than one record, ask user which record they want.
      [item,itemIndex]=listgui({out.summary},'Please choose a record to read');
      if isempty(item), disp('User cancelled chosing record to read!'); data=[]; return; end          
    else
      % Only one record, just use it
      itemIndex = 1;
    end
    recType=out(itemIndex).type;
    recSubType=out(itemIndex).subtype;
    
    clear item itemIndex out
  end
  
  % Find the desired record type
  dataRec_i = [];
  for n=1:length(hdr.bxh{1}.datarec)
    if isfield(hdr.bxh{1}.datarec{n},'ATTRS') & isfield(hdr.bxh{1}.datarec{n}.ATTRS,'type') ...
      & strcmp(hdr.bxh{1}.datarec{n}.ATTRS.type.VALUE,recType)
      dataRec_i = [dataRec_i, n];
    end
  end
  % Check that a record was found
  if isempty(dataRec_i),
    emsg=sprintf('No records of type %s found in header!',recType); error(emsg);
  end
  
  % Find the desired record subtype
  if isempty(recSubType)
    % Record subtype not specified.  If there is only one record with a
    % matching type, use it.  Otherwise error.
    if length(dataRec_i) > 1,
      emsg=sprintf('More than one record of type %s found in header.  Please specify subtype',recType); error(emsg);
    end
  else
    % Record subtype specified, look for match within the datarecs which match recType
    dataRecToRemove=[];
    for n=1:length(dataRec_i)
      % Remove entries with non-matching subtypes (no subtype is implicitly = '0')
      if isfield(hdr.bxh{1}.datarec{dataRec_i(n)}.ATTRS,'subtype')
        currSubType = hdr.bxh{1}.datarec{dataRec_i(n)}.ATTRS.subtype.VALUE;
      else
        currSubType = '0';
      end
      if ~strcmp(currSubType,recSubType)
        dataRecToRemove=[dataRecToRemove, n];
      end
    end
    dataRec_i(dataRecToRemove)=[];
    % Check that a single record matched
    if isempty(dataRec_i),
      emsg=sprintf('No records of type %s and subtype %s found in header!',recType,recSubType);
      error(emsg);
    end
    if length(dataRec_i) > 1
      emsg=sprintf('More than one record of type %s and subtype %s found in header!  Header invalid!',recType,recSubType);
      error(emsg);
    end
  end
  
  % Get the size of the data
  try ndims = length(hdr.bxh{1}.datarec{dataRec_i}.dimension(:));
  catch emsg = sprintf('Unable to find field hdr.bxh{1}.datarec{%d}.dimension(:)',dataRec_i); error(emsg); end
  
  dimSize = zeros(1,ndims);
  for n=1:ndims
    % Get size of dimensions
    try dimSize(n) = hdr.bxh{1}.datarec{dataRec_i}.dimension{n}.size{1}.VALUE;
    catch emsg = sprintf('Unable to find field hdr.bxh{1}.datarec{%d}.dimension{%d}.size{1}.VALUE',dataRec_i,n); error(emsg); end
    
    % Get image type (default to '')
    try type{n} = hdr.bxh{1}.datarec{dataRec_i}.dimension{n}.ATTRS.type{1}.VALUE;
    catch type{n} = ''; end
  end
  
  % Get the byte order
  try byteOrder = hdr.bxh{1}.datarec{dataRec_i}.byteorder{1}.VALUE;
  catch emsg = sprintf('Unable to find field hdr.bxh{1}.datarec{%d}.byteorder{1}.VALUE',dataRec_i); error(emsg); end
  if strcmp(byteOrder,'msbfirst')
    byteOrder = 'b';
  elseif strcmp(byteOrder,'lsbfirst');
    byteOrder = 'l';
  else
    emsg = sprintf('Byte order %s unsupported!',byteOrder); error(emsg);
  end
  
  % Get the file offset(s)
  try
    % Get the number of offsets
    fileOffsets = cell(1,length(hdr.bxh{1}.datarec{dataRec_i}.fileoffset(:)));
  catch
    % Not specified, use 0 for all offsets
    fileOffsets = {0};
  end
  % Get each offset
  if isempty(fileOffsets{1})
    for n=1:length(fileOffsets)
      try fileOffsets{n} = hdr.bxh{1}.datarec{dataRec_i}.fileoffset{n}.VALUE;
      catch emsg = sprintf('Unable to find field hdr.bxh{1}.datarec{%d}.fileoffset(%d).VALUE',dataRec_i,n); error(emsg); end;
    end
  end
  
  % Get the element type
  try elementType = hdr.bxh{1}.datarec{dataRec_i}.elementtype{1}.VALUE;
  catch emsg = sprintf('Unable to find field hdr.bxh{1}.datarec{%d}.elementtype{1}.VALUE',dataRec_i); error(emsg); end
  
  % Calculate the size of each element
  switch elementType
  case {'int8', 'uint8','ascii'}
    elementBytes = 1;
  case {'int16','uint16'}
    elementBytes = 2;
  case {'int32','uint32','float32'}
    elementBytes = 4;
  case {'float64'}
    elementBytes = 8;
  otherwise
    emsg = sprintf('Element type, %s, unsupported by readbxhdata!',elementType); error(emsg);
  end
  
  % Determine precision and outputprecision to use in reading data (see fread)
  % Use native output precision for elements.
  % NOTE: must be able to evalf(outPrecision,0) to get a 1x1 array of type elementType.
  switch elementType
  case {'int8','uint8','int16','uint16','int32','uint32'}
    precision=elementType;
    outPrecision=elementType;
  case 'float32'
    precision=elementType;
    outPrecision='single';
  case 'float64'
    precision=elementType;
    outPrecision='double';
  case 'ascii'
    precision='char';
    outPrecision='char';
  otherwise
    emsg = sprintf('Element type, %s, unsupported by readbxhdata!',elementType); error(emsg);
  end
  
  % Calculate the size of the data in bytes
  dataSize = elementBytes*prod(dimSize);
  
  % Get the recordSize
  try recordSize = hdr.bxh{1}.datarec{dataRec_i}.recordsize{1}.VALUE;
  catch
    % If not specified, calculate as the size of the data
    recordSize = dataSize;
  end
  
  % Check that the recordSize is >= the dataSize
  % TODO: Is this necessary or will an XML Schema handle it???
  if recordSize < dataSize
    emsg='recordsize is smaller than the size of the specified data!'; error(emsg);
  end
  
  % Get the filename string  
  % TODO: Add support for data in same file as header
  try filenames = cell(1,length(hdr.bxh{1}.datarec{dataRec_i}.filename(:)));
  catch emsg = sprintf('Unable to find field hdr.bxh{1}.datarec{%d}.filename(:)',dataRec_i); end
  for n=1:length(filenames)
    try filenames{n} = hdr.bxh{1}.datarec{dataRec_i}.filename{n}.VALUE;
    catch emsg = sprintf('Unable to find field hdr.bxh{1}.datarec{%d}.filename{%d}.VALUE',dataRec_i,n); error(emsg); end
  end
  
  % Get the filenameprintfdimesions field if it exists
  try filenamePrintfDimensions = hdr.bxh{1}.datarec{dataRec_i}.filenameprintfdimensions{:}.VALUE; 
  catch filenamePrintfDimensions = []; end
  
  % Construct the filenames based on the possible filename formats
  if ~isempty(filenamePrintfDimensions)
    % Filename is a printf string which must be evaluation to construct the filenames
    
    % Check that there is only one filename
    if length(filenames) ~= 1
      emsg='Cannot use more than one filename when using printf method to specify filename'; error(emsg);
    end
    
    % Get the filename printf origins (defaults to all zeros)
    try filenamePrintfOrigins = hdr.bxh{1}.datarec{dataRec_i}.filenameprintforigins{:}.VALUE;
    catch filenamePrintfOrigins = zeros(1,length(filenamePrintfDimensions)); end
    
    % --- Construct the filenames ---
    % Calculated the correct order to increment the dimensions.
    [sortedDims,sortedDims_i] = sort(filenamePrintfDimensions);
    
    % Calculate the number of files in each dimension:
    %   If any of the slowest-moving dimensions are missing, the
    %   slowest-specified dimension will be the product of the  
    %   ranges of it and the following missing dimensions.
    % NOTE: printfDimSize is in same order as sortedDims
    if any(diff(sortedDims)~=1)
      emsg='Invalid filenamePrintfDimensions!  Must not skip any dimensions!'; error(emsg);
    end
    printfDimSize=dimSize(sortedDims);
    % Handle the slowest-moving dimensions;
    printfDimSize(end) = prod(dimSize(sortedDims(end):length(dimSize)));
        
    % Calculate the number of filenames & initialize a filenames array
    printfString = filenames{1};  % Keep the printf string
    filenames = cell(1,prod(printfDimSize));
    
    % Initialize cell array of current dimension values to filenamePrintfOrigins
    dimCounters = cell(1,length(filenamePrintfOrigins));
    for n = 1:length(filenamePrintfOrigins), dimCounters{n}=filenamePrintfOrigins(n); end
    
    % Construct the first filename
    filenames{1} = sprintf(printfString,dimCounters{:});
    
    % Construct the rest of the filenames
    for file=2:length(filenames)
      % Update the dimCounters
      dim=1;  % Use lowest dim first
      dimCounters{sortedDims_i(dim)} = dimCounters{sortedDims_i(dim)}+1; % Increment the counter in the lowest dim
      while dimCounters{sortedDims_i(dim)} > printfDimSize(dim)
        % If the pointer for the current dim is greater than the number of elements in the current dim 
        % set all of the lower dims to 1 and increment the next higher dim.
        dimCounters{sortedDims_i(1:dim)} = 1;
        dim=dim+1;
        dimCounters{sortedDims_i(dim)} = dimCounters{sortedDims_i(dim)}+1;
      end % End update dimCounters
      
      % Construct the filename
      filenames{file} = sprintf(printfString,dimCounters{:});
    end % End construct printf filenames 
  end
  
  % Check that fileOffsets are compatible with the number of filenames
  if ~any(length(fileOffsets) == [length(filenames) 1])
    % There must be 1 or # filenames number of fileOffsets
    emsg = sprintf('Number of file offsets (%d) and number of filenames (%d) not compatible!',length(filesOffsets),length(filenames));
    error(emsg);
  end
  
  % Get the length of the data in each file at each offset
  try
    % Get the number of fileData sizes specified
    fileDataSizes = cell(1,length(hdr.bxh{1}.datarec{dataRec_i}.filerecordsize(:)));
  catch
    % Not specified, assume that fileDataSizes is even divided among all the
    % offsets in all the files 
    % Convert fileDataSizes to number of elements (since fread use number of elements, not bytes)
    
    % Determine the number of file fragments
    if length(fileOffsets) == 1
      % Only one offset per file
      nFragments = length(filenames); 
    else
      % Multiple offsets into each file
      nFragments = 0;
      for n=1:length(filenames)
        nFragments = nFragments+length(fileOffsets{n});
      end
    end
    % Calcaulte fileDataSizes
    fileDataSizes = {dataSize/nFragments/elementBytes};    
  end
  % Get each element of fileDataSizes
  if isempty(fileDataSizes{1})
    for n=1:length(fileDataSizes)
      % Read filedatasize field
      % Convert fileDataSizes to number of elements (since fread use number of elements, not bytes)
      try fileDataSizes{n} = hdr.bxh{1}.datarec{dataRec_i}.filerecordsize{n}.VALUE/elementBytes;
      catch emsg = sprintf('Unable to find field hdr.bxh{1}.datarec{%d}.filerecordsize(%d).VALUE',dataRec_i,n); error(emsg); end;
    end
  end
  
  % Check that fileDataSizes are compatible with fileOffsets & filenames
  if ~any(length(fileDataSizes) == [length(filenames) 1])
    % There must be 1 or # filenames number of fileDataSizes
    emsg = sprintf('Number of file data sizes (%d) and number of filenames (%d) not compatible!',length(filesDataSizes),length(filenames));
    error(emsg);
  end
  
  fileDataSizes_i = 1;  % Initialize index into fileDataSizes to 1
  for fileOffsets_i=1:length(fileOffsets)
    % If there is more than one fileDataSize track fileOffsets_i
    if length(fileDataSizes) ~= 1, fileDataSizes_i = fileOffsets_i; end
    
    % Check the contents of each cell
    if ~any(length(fileDataSizes{fileDataSizes_i}) == [1 length(fileOffsets{fileOffsets_i})])
      % There must be 1 or # offsets number of fileDataSizes
      emsg = sprintf('Incompatible # of file offsets (%d) and # of file data sizes (%d) for file #%d\n  (%s)', ...
        length(fileOffsets{fileDataSizes_i}),length(fileDataSizes{fileOffsets_i}),fileOffsets_i,filenames{fileOffsets_i});
      error(emsg);
    end
  end
  
  % Construct the baseURL
  baseURL=[fileparts(hdr.BASE),filesep];
  
  % Read the data
  data=local_readdata(baseURL,filenames,fileOffsets,fileDataSizes,byteOrder,precision,outPrecision,dimSize);
  
catch
  data=[];    % Return an empty matrix
  if isempty(emsg)
    if isempty(lasterr)
      emsg='An unidentified error occurred!';
    else
      emsg=lasterr;
    end
  end
  error(emsg);
end

function data=local_readdata(baseURL,filenames,fileOffsets,fileDataSizes,byteOrder,precision,outPrecision,dimSize)
% local_readdata - Read data from files
%
%    data=local_readdata(baseURL,filenames,fileOffsets,fileDataSizes,byteOrder,precision,outPrecision,dimSize)
%
%       baseURL      - baseURL for filenames, can be ''
%       filenames    - cell array of names of files to read
%       fileOffsets  - cell array of vectors of offsets (in bytes) into each file
%                      NOTE: If there is only one cell, the same offsets used for each file
%       fileDataSizes- cell array of vectors of segment lengths (in # elements) to read from 
%                      each offset in each file.
%                      NOTE: If there is only one cell, the same segment length will be used for each file
%                      NOTE: If there is only one element in a cell, the same segment length
%                            will be used for each offset in the corresponding file.
%       byteOrder    - string specifying byte order for reading file (passed to fopen)
%       precision    - precision passed to fread for reading
%    outPrecision    - precision of output
%       dimSize      - vector of dimension of output array
%       
%               data - Data read (empty if error)

p=[];    % Initialize progress bar handle for catch
emsg=''; % Initialize error message for catch
try
  % If dimSize is a single value, make it 2D for MATLAB
  if length(dimSize)==1, dimSize(2)=1; end
  
  % Allocate memory for output array
  if strcmp(outPrecision,'double');
    data=zeros(dimSize);            
  else    
    data=repmat(feval(outPrecision,0),dimSize);
  end
  data_i = 1;                       % Index to current free element in output array
  data_i_end = (prod(dimSize) +1);  % Correct data_i when data is full (so that it isn't calculated each loop)
  currOffsets = fileOffsets{1};     % Initialize to use 1st fileOffset
  currDataSizes = fileDataSizes{1}; % Initialize to use 1st fileDataSizes
  
  % Read each file
  nfiles = length(filenames);
  p=progbar(sprintf('Reading 0 of %d files (%s) ...',nfiles,filenames{1}));
  for file = 1:length(filenames)
    % Update progress bar
    if ~ishandle(p), emsg='User abort'; error(emsg); end
    progbar(p,file/nfiles,sprintf('Reading %d of %d files (%s)...',file,nfiles,filenames{file}));
    
    % Open the file
    % Note that all filenames are relative to the path of the bxhfile
%    sprintf('Calling fopenlocation for %s with baseURL %s', filenames{file}, config.base)
    [fid,message] = fopenlocation(filenames{file}, {'r', byteOrder}, baseURL);
    if fid==-1, emsg=message; end
    
    % If there is more than one fileOffsets, then set currOffsets
    % to increment through for each file.  Otherwise, use the same
    % value for all fileOffsets (as initialized)
    if length(fileOffsets) ~= 1
      currOffsets = fileOffsets{file};
    end
    
    % If there is more than one fileDataSizes, then set currDataSizes
    % to increment through for each file.  Otherwise, use the same
    % value for all fileDataSizes (as initialized)
    if length(fileDataSizes) ~= 1
      currDataSizes = fileDataSizes{file};
    end
    
    % Read each block in the file
    currDataSize = currDataSizes(1);  % Initialize to use first element in currDataSize vector
    for block = 1:length(currOffsets)
      % Go to the proper location in the file
      if fseek(fid,currOffsets(block),'bof')
        emsg = ferror(fid); error(emsg);
      end
      
      % If currDataSize only has one element, use it for all offsets (as initialized)
      % Otherwise, increment through for each file.
      if length(currDataSizes) ~= 1
        currDataSize = currDataSizes(block);
      end
      
      % Check that there is enough room for the next segment
      if data_i+currDataSize > data_i_end
        emsg = 'Too much data in files for specified data size'; error(emsg);
      end
      
      % Read the file
      [data(data_i:(data_i+currDataSize-1)),count] = fread(fid,currDataSize,precision);
      if count ~= currDataSize
        emsg=sprintf('Unable to read %d bytes (%d needed) in %s.',count,currDataSize,filenames(file));
        error(emsg);
      end
      % Update index to current free element
      data_i = data_i+currDataSize; 
    end
    fclose(fid);
  end  
  delete(p); p=[]; % Delete progress bar (and set to [] for catch)
  
  % Check that the output array was filled
  if data_i ~= data_i_end
    emsg = 'Not enough data in files for specified data size'; error(emsg);
  end
  
catch
  data=[];    % Return an empty matrix
  delete(p); % Delete progress bar
  if isempty(emsg)
    if isempty(lasterr)
      emsg='An unidentified error occurred!';
    else
      emsg=lasterr;
    end
  end
  error(emsg);
end

function out=local_gensummaries(hdr)
%LOCAL_GENSUMMARIES - Generate summaries for each record in BXH file.
%
%  Displays information from BXH header
%
%  out=local_gensummaries(bxhhdr)
%
%   bxhhdr - Parsed BXH header.
%      out - array of structures (one element for each datarec)
%            out.summary - Nicely formated summary string 
%            out.type    - type of current record
%            out.subtype - subtype of current record

out=repmat(struct('summary','','type','','subtype',''),1,length(hdr.bxh{1}.datarec));
descriptions = cell(size(out));
for n=1:length(out)
  % TODO: No need to check for type field, readbxhhdr checks this!
  % Get type
  out(n).type='Not Defined';
  if isfield(hdr.bxh{1}.datarec{n}.ATTRS,'type')
    out(n).type=hdr.bxh{1}.datarec{n}.ATTRS.type.VALUE;
  end
  
  % Get subtype
  out(n).subtype='0';
  if isfield(hdr.bxh{1}.datarec{n}.ATTRS,'subtype')
    out(n).subtype=hdr.bxh{1}.datarec{n}.ATTRS.subtype.VALUE;
  end
  
  % Get Description
  descriptions{n}='No Description';
  if isfield(hdr.bxh{1}.datarec{n},'description')
    descriptions{n}=hdr.bxh{1}.datarec{n}.description{1}.VALUE;
  end

  % Construct nicely formated summary string
  out(n).summary = sprintf('%s     (type = %s, subtype = %s)', ...
    descriptions{n},out(n).type, out(n).subtype);
end

% Construct nicely formated summary string
% descLengths=cellfun('length',descriptions);
% str=sprintf('%%-%ds (type = %%s, subtype = %%s)',max(descLengths));
% for n=1:length(out)
%   out(n).summary = sprintf(str,descriptions{n},out(n).type, out(n).subtype);
% end

% Modification History:
%
% $Log: readbxhdata.m,v $
% Revision 1.35  2005/02/03 16:58:41  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.34  2003/10/22 15:54:38  gadde
% Make some CVS info accessible through variables
%
% Revision 1.33  2003/05/30 21:38:44  michelich
% Handle allocation of memory for 1D data properly.
%
% Revision 1.32  2003/05/30 18:33:46  michelich
% Allow passing bxhref, but prompting from record type in GUI.
%
% Revision 1.31  2003/04/21 20:22:31  michelich
% Added GUI to chose datarec.
%
% Revision 1.30  2003/04/21 20:01:01  michelich
% Return data in an array of the native precision.
%
% Revision 1.29  2003/01/10 22:07:05  Administrator
% Random small fixes.  Generic random comment.
%
% Revision 1.28  2003/01/09 20:28:17  gadde
% readxml will now give a BASE field.  Use that instead of BXHFILE.
%
% Revision 1.27  2003/01/08 19:27:28  michelich
% Note: Revision 1.26 comments should have been: "Interpret version as a string"
% Check version for parsed & unparsed files.
% Require bxh namespace declaration and a version (instead of just warning user).
%
% Revision 1.26  2003/01/08 19:04:35  michelich
% Require bxh namespace declaration.
% Include no namespace version on XPaths which are being forced to be strings.
%
% Revision 1.25  2003/01/08 17:27:07  gadde
% New method for deleteonclose -- still doesn't work on Windows yet :(
%
% Revision 1.24  2002/12/18 18:29:28  michelich
% Missing semicolon
%
% Revision 1.23  2002/12/18 18:28:38  michelich
% Fixed search for matching subtypes again
%
% Revision 1.22  2002/12/18 18:20:23  michelich
% Fixed search for matching subtypes
%
% Revision 1.21  2002/12/12 17:29:21  michelich
% Added check for implicitly defined subtype = '0'
%
% Revision 1.20  2002/12/11 15:15:22  michelich
% Fixed number of arguments check.
% Added support for reading ASCII data.
%
% Revision 1.19  2002/12/10 15:44:12  michelich
% Read header using readbxhhdr.
% Use BXHFILE field created by readbxhhdr to determine base path for filenames.
% Added ascii element type.
% Added better error messages when fopenlocation fails.
%
% Revision 1.18  2002/12/09 19:56:29  michelich
% Added support for reading any datarec.
%
% Revision 1.17  2002/11/21 14:29:06  michelich
% Renamed readxmlimagedata.m to readbxhdata.m
%
% Revision 1.16  2002/11/08 15:51:42  michelich
% Added support for datarec type="image" instead of imagedata elements.
% Corrected several sprintf error message strings (replaced n's with %d's).
%
% Revision 1.15  2002/10/09 20:35:17  crm
% Corrected spelling of localloc
%
% Revision 1.14  2002/10/07 20:39:20  gadde
% Added fclose in the appropriate place.
%
% Revision 1.13  2002/10/02 21:04:47  gadde
% Consolidated common code from fopenlocation and loadlocation into grablocation.
%
% Revision 1.12  2002/10/02 14:36:36  michelich
% Updated for loadlocation syntax change.
% Removed unnecessary config variable.
% Updated comments and error messages.
%
% Revision 1.11  2002/10/02 00:59:18  gadde
% Now supports reading BXH files from URLs that are supported by
% loadlocation and fopenlocation.
%
% Revision 1.10  2002/09/25 18:29:53  gadde
% Now accepts already-digested XML struct as an argument.
%
% Revision 1.9  2002/09/09 19:53:49  gadde
% /mriheader -> /bxh
%
% Revision 1.8  2002/08/16 19:37:46  gadde
% minor field name changes
%
% Revision 1.7  2002/08/15 16:37:36  michelich
% Added support for fully qualified filenames
%
% Revision 1.6  2002/08/13 15:02:13  michelich
% Changed file selection filter to *.bxh
%
% Revision 1.5  2002/08/01 17:24:40  michelich
% Added check that filenameprintfdimensions has no gaps
% Simplified handling of filenameprintfdimensions for efficiency
%
% Revision 1.4  2002/07/30 22:19:50  michelich
% Handle missing dimensions in printf filename generate method.
% Added check that file exists before opening it.
%
% Revision 1.3  2002/07/29 23:58:50  michelich
% Added support for expanded use of filedatasize field
% Changed name of XML element fileoffset to filedataoffset
%
% Revision 1.2  2002/07/25 16:32:55  michelich
% Added more error checking
%
% Revision 1.1  2002/07/25 16:21:35  michelich
% Original
%
