function varargout=readmr(varargin)
%READMR Read MR images from filename or structure.
%
%   mrstruct = readmr;  % Use GUI
%   mrstruct = readmr(filenames, typespec, dataselect, '=>returnelemtype');
%   mrstruct = readmr(filenames, typespec, dataselect, '=>returnelemtype', 'NOPROGRESSBAR');
%   data = mrstruct.data;
%   info = mrstruct.info;
%
%   mrinfostruct = readmr('=>INFOONLY'); % Use GUI, only read info
%   mrinfostruct = readmr(filenames, typespec, '=>INFOONLY');
%   mrstruct = readmr(mrinfostruct, dataselect, '=>returnelemtype');
%   mrstruct = readmr(mrinfostruct, dataselect, '=>returnelemtype', 'NOPROGRESSBAR');
%   readmr(mrinfostruct, '=>CLEANUP')
%
%   READMR takes a filename or a cell array of filenames along
%   with an optional string specifying the type of the returned
%   data, an optional data selection array and an optional type
%   specification, and returns the selected data, as well as a new
%   header that describes the returned data, in a structure (mrstruct).
%   The return type, typespec, and data selector must be specified
%   in that order, but any or all may be omitted.
%   See below for details on specific arguments.
%
%   If the caller sends the argument '=>INFOONLY', readmr will
%   do everything except physically read the data, and return the
%   current state (mrinfostruct).  This return value can be used
%   to subsequent calls to readmr in place of the "filenames"
%   and "typespec" arguments.  This can be used, for example, to
%   gather info about data dimensions and then, using this information
%   to read data in smaller pieces by constructing appropriate
%   "dataselect" arguments.  As above, the "typespec", "dataselect",
%   and "returnelemtype" arguments can be omitted, but must be specified
%   in the order given above.
%
%   The '=>CLEANUP' argument tells readmr to clean up all temporary
%   files it kept around for use with "mrinfostruct".  If using
%   '=>INFOONLY', you should always eventually call '=>CLEANUP'
%   after you are done using the mrinfo struct.
%
%   Argument details:
%
%   The "returnelemtype" argument, if specified, must start with '=>'
%   and specifies the type of the data returned in mrstruct.data.
%   If not specified, it is assumed to be '=>double'.  If '=>native' is
%   specified, the date will be returned using the type it is on disk.
%
%   The data selection array "selector" is a cell array of numeric
%   arrays which specify the subset of data you wish returned.
%   If not specified or empty, readmr returns all the data.
%   The first four numeric arrays refer to x, y, z, and t
%   dimensions, respectively, and the rest are the other dimensions
%   in the data, in the order in which they appear in the data,
%   from fastest-moving to slowest-moving.
%   Each numeric array is a list of indices, e.g.:
%     { [], '', [1:3], [1,2,3,4], 3 }
%   which says "grab all x and y points, only the z points from 1
%   to 3, time points 1 to 4, and the 3rd point in the fifth
%   dimension.  Empty strings or empty arrays mean grab everything,
%   and the x, y, z, and t dimensions must be specified, even if
%   they don't exist in the data.
%
%   The type specification "typespec" consists either of a simple
%   string from the list of complete data formats below, or a
%   cell array that looks like the following:
%      { formatstring, imageparams... }
%   where "formatstring" is one of the imcomplete data formats,
%   "imageparams" is a list of format-specific parameters required
%   to fully parse the file.  Default is 'Auto'.
%   Completely specified data formats (don't require further parameters):
%     [GE]      'Signa5', 'SignaXIMG'
%     [DICOM]   'DICOM_Slice', 'DICOM_Volume', 'DICOM', 'DICOM_Search'
%     [Analyze] 'Analyze7.5_SPM'
%     [XML]     'BXH'
%     [Other]   'Auto'
%   Incompletely specified data formats (require further parameters):
%     [Raw]     'Float', 'Volume', 'Raw'
%     [DICOM]   'DICOM_Slice', 'DICOM_Volume', 'DICOM', 'DICOM_Search'
%     [XML]     'BXH'
%   How to use format-specific image parameters:
%     { 'Float', dimsizes }
%     { 'Volume', dimsizes }
%     { 'DICOM', 'dicom-dict.mat' } % same for other DICOM_* types
%     { 'BXH', datarectype, datarecsubtype }
%     { 'Raw', dimsizes, pixelType, byteOrder, hdrSz, opt_recSz, opt_dimorder }
%   "dimsizes" is a numeric array specifying the sizes of the
%   dimensions in the data, in order from fastest-moving to
%   slowest-moving.  "opt_dimorder" is an optional cell array
%   of strings specifying the labels of the dimensions in the
%   data, e.g. { 'x', 'y', 'z', 't' } (this is the default).
%   opt_recSz indicates how many bytes to read ([] or Inf means
%   to read the rest of the file, which is the default behavior).

% ------------------- Note on backwards compatibility -------------------
% READMR also supports the following "old-style" arguments for backwards
%   compatibility.  Note that this does not include all of the possibile
%   arguments to the old function.
%
%   [srs,name,params]=readmr(fName,xSz,ySz,zSz,cannedFormat);
%   [srs,name,params]=readmr(fName,xSz,ySz,zSz,hdrSz,pixelType,byteOrder,allInOne,startExt);
%
%   If the format has a readable header, any values passed in xSz,ySz,zSz 
%     will be confirmed using the information in the header.  Use [] for
%     xSz, ySz, and/or zSz to just use the information from the header.
%
%   fName is the full path and name of the file with the MR data.
%   xSz,ySz,zSz are the x,y,z sizes of the images.
%   cannedFormat is one of Float, Volume, Signa5, ScreenSave,
%     Analyze7.5_SPM, DICOM_Slice, DICOM_Volume, DICOM_AVW_VolumeFile,
%     ANMR, EP, Signa4, or CORITechs
%   hdrSz is the number of header bytes to skip.
%   pixelType specifies how the pixels are stored in the file:
%     'int16', 'uint16', 'float32', 'uchar', etc.
%     It is passed to FREAD as the precision argument.
%   byteOrder is 'l' for little-endian, 'b' for big-endian,
%     or 'd' for VAX D floating point.
%     It is passed to FOPEN as the MACHINEFORMAT argument.
%   allInOne is 1 if all the images are in one file, else 0.
%     If 0, fName must not include extension.  See next argument.
%   startExt is the numeric file extension to start with.
%     Extension is zero-padded to 3 characters.
%
%   srs is an xSz by ySz by zSz array of the MR data.
%   name is the name of the file which was read.
%   params is a cell array of the parameters used to read the MR data.
% ----------------- End: Note on backwards compatibility -----------------

% CVSId = '$Id: readmr.m,v 1.73 2005/06/17 15:22:05 gadde Exp $';
% CVSRevision = '$Revision: 1.73 $';
% CVSDate = '$Date: 2005/06/17 15:22:05 $';
% CVSRCSFile = '$RCSfile: readmr.m,v $';

if nargin == 0 | (isnumeric(varargin{1}) & length(varargin{1}) == 1 & varargin{1} == -1) ...
    | (ischar(varargin{1}) & strcmp(varargin{1}, '=>INFOONLY')) % LAUNCH GUI
  % Launch GUI if there are no input arguments or if the first input
  % argument is -1.  NOTE: The purpose of the first input argument -1
  % case is to provide a mechanism to specify GUI defaults when launching
  % the GUI as implemented in local_initgui(). (e.g. default to a 3D image,
  % default directory, etc...).  This could be implemented many other ways.

  % Also, allow for using the GUI when specifying '=>INFOONLY'.  This is
  % useful when other programs want to use the same calling conventions
  % as READMR (including defaulting to a GUI) but don't want to
  % read the data.
  
  % Attempt to read parameters using readmrgui
  [argsin,workspaceVar]=readmrgui(varargin{2:end});
  
  % Handle non-error cases.
  % NOTE: Could also return a message from readmrgui if more
  %       non-error cases are necessary.
  if isempty(argsin)
    if isempty(workspaceVar)
      % User cancelled, delete GUI and return emptys for output.
      if nargout > 0
        varargout=cell(nargout,1);
      else
        varargout={[]};
      end
      return;
    else
      % User chose a base workspace variable, try to use it
      mrstruct=evalin('base',workspaceVar);
      if ~isstruct(mrstruct) & (isnumeric(mrstruct) | islogical(mrstruct))
        % It is an numeric array, create an mrstruct for it
        mrstruct=createmrstruct(mrstruct);
      elseif ~(isstruct(mrstruct) & isfield(mrstruct,'info') & isfield(mrstruct,'data'))
        % It is not a valid mrstruct structure
        error(sprintf('Variable "%s" is not a numeric array or mrstruct',workspaceVar));
      end
      % Return the variable
      varargout{1}=mrstruct;
      return;
    end
  end

  if length(varargin) > 0 & ischar(varargin{1}) & strcmp(varargin{1}, '=>INFOONLY')
    % If user wanted INFOONLY, just return the mrstruct
    % TODO: What about any other arguments (e.g. selector) ???
    if nargin > 2 | ~iscell(argsin{2}) | ~all(cellfun('isempty',argsin{2}))
      warning('Ignoring all arguments specified in GUI other than mrinfo structure!');
    end
    if nargout > 1
      error('Too many output arguments.');
    end
    varargout(1) = argsin(1);
    return
  end

  % Continue on to read data using GUI specified argsin
  guiIsInfoStruct = 1;  % So that GUI mrinfo gets cleaned up.

else
  % COMMAND LINE READING OF DATA
  argsin = varargin;
  guiIsInfoStruct = 0;
end

% ------------------------ Read MR headers and data -----------------------
% construct list of supported "complete" formats
formatsFields = {'format','matSz','hdrSz','pixelType','byteOrder','dimorder'};
formats = { ...
    'Signa5', [], 7904, 'int16', 'b', '' ; ...
    'SignaXIMG', [], 8432, 'int16', 'b', '' ; ...
    'Analyze7.5_SPM', [], 0, 'int16', 'l', '' ; ...
    'DICOM', [], [], [], [], '' ; ...
    'DICOM_Search', [], [], [], [], '' ; ...
    'DICOM_Slice', [], [], [], [], '' ; ...
    'DICOM_Volume', [], [], [], [], '' ; ...
    'BXH', [], [], '', '', '' ; ...
    'Float', [], 0, 'float32', 'l', '' ; ...
    'Volume', [], 0, 'int16', 'l', '' ; ...
    'Raw', [], [], '', '', '' ; ...
    'Auto', [], [], '', '', '' ...
  };
% Legacy formats that need header readers:
% [Legacy]  'ANMR', 'EP', 'Signa4', 'CORITechs'
%  'ANMR', [], 80, 'int16', 'b', '' ; ...
%  'EP', [], 0, 'float32', 'd', '' ; ...
%  'Signa4', [], 14336, 'int16', 'b', '' ; ...
%  'CORITechs', [], 0, 'uint8', 'l', '' ; ...
formats = cell2struct(formats,formatsFields,2);
clear formatsFields

typesizes = struct('type', ...
                   {'uchar', 'schar', ...
                    'int8', 'int16', 'int32', 'int64', ...
                    'uint8', 'uint16', 'uint32', 'uint64', ...
                    'single', 'float32', 'double', 'float64'}, ...
                   'matlabtype', ...
                   {'uint8', 'int8', ...
                    'int8', 'int16', 'int32', 'int64', ...
                    'uint8', 'uint16', 'uint32', 'uint64', ...
                    'single', 'single', 'double', 'double'}, ...
                   'size', ...
                   {1, 1, ...
                    1, 2, 4, 8, ...
                    1, 2, 4, 8, ...
                    4, 4, 8, 8 });

numinputargs = length(argsin);
% end prelim stuff


error(nargchk(0,9,numinputargs));

p=[];    % Initialize progress bar handle for catch
emsg=''; % Initialize error message for catch

% input arguments
inputlocs={};
selector=[];
typespec=[];
argreturnelemtype = '';
infoonly = 0;

% used internally
inputurls={};
inputfiles={};
inputsizes=[];
downloaded={};
mrparams=[];
inputisinfo = 0;
verbose = 0;
noprogressbar = 0;

% output arguments
info=[]; % also can be input
srs=[];

numargsin = length(argsin);
  
try
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% BACKWARDS-COMPATIBILITY LAYER %%%
  %%% Check for and handle "old-style" readmr parameters
  if numargsin > 4 & ...
      ischar(argsin{1}) & ...
      isnumeric(argsin{2}) & ...
      isnumeric(argsin{3}) & ...
      isnumeric(argsin{4})
    if nargout > 3, error('Too many output arguments.'); end
    fName = argsin{1};
    xSz = argsin{2};
    ySz = argsin{3};
    zSz = argsin{4};
    cannedFormat = '';
    [hdrSz, pixelType, byteOrder, allInOne, startExt] = deal([]);
    % Disallow wildcards since "old-style" did not do wildcard expansion.
    if any(fName == '*')
      error('Wildcards not allowed in "old-style" readmr parameters');
    end
    if ischar(argsin{5})
      if numargsin ~= 5
        error('Extra arguments found');
      end
      % Canned formats from old readmr.
      oldCannedFormats={'Float','Volume','Signa5','ScreenSave', ...
          'Analyze7.5_SPM','DICOM_Slice','DICOM_Volume','DICOM_AVW_VolumeFile', ...
          'ANMR','EP','Signa4','CORITechs'};

      % Make sure this is a recognized format and get proper capitalization
      % since old readmr was case insensitive.
      cannedFormat = argsin{5};
      f=find(strcmpi(cannedFormat,oldCannedFormats));
      if isempty(f), emsg=sprintf('Unknown canned format "%s"!',cannedFormat); error(emsg); end
      cannedFormat=oldCannedFormats{f};  
      
      %TODO: Handle other canned formats that are not supported by readmr.
      switch cannedFormat
        case { 'Float', 'Volume' }
          mrstruct = readmr(fName, { cannedFormat, [xSz ySz zSz] }, 'NOPROGRESSBAR');
        case 'Signa5'
          [newparams,emsg] = readmrhdr(fName, 'Signa5');
          if isempty(newparams), error(emsg); end
          % ~allInOne
          fNames = {};
          [pth,nm,ext]=fileparts(fName); % Strip extension
          for z=1:newparams.matSz(3);    % Construct filename
            fNames{z} = sprintf('%s.%03d',fullfile(pth,nm),z);
          end
          mrstruct = readmr(fNames, 'Signa5', 'NOPROGRESSBAR');
          fName = fNames{end};  % Old READMR returned last filename
        case 'ScreenSave'
          % ScreenSave is just a single Signa5 file.
          mrstruct = readmr(fName, 'Signa5', 'NOPROGRESSBAR');        
        case 'EP'
          % Read EP as a Raw format using specified matrix size. (data in one file)
          fmt.hdrSz=0; fmt.pixelType='float32'; fmt.byteOrder='d'; fmt.recSz = xSz.*ySz.*zSz.*4;
          mrstruct = readmr(fName, { 'Raw', [xSz ySz zSz], fmt.pixelType, fmt.byteOrder, fmt.hdrSz, fmt.recSz}, 'NOPROGRESSBAR');
        case {'ANMR','Signa4','CORITechs'}
          % Read ANMR, Signa4, CORITechs  as a Raw format using specified
          % matrix size. (data in multiple files)          
          % CORITechs starts at 000, the others start at 001
          if strcmp(cannedFormat,'CORITechs'), startExt = 0; else startExt = 1; end
          fNames = {};
          [pth,nm,ext]=fileparts(fName); % Strip extension
          for z=1:zSz                    % Construct filename
            fNames{z} = sprintf('%s.%03d',fullfile(pth,nm),z-1+startExt);
          end
          switch cannedFormat
            case 'ANMR', fmt.hdrSz=80; fmt.pixelType='int16'; fmt.byteOrder='b'; fmt.recSz = xSz.*ySz.*2;
            case 'Signa4', fmt.hdrSz=14336; fmt.pixelType='int16'; fmt.byteOrder='b'; fmt.recSz = xSz.*ySz.*2;
            case 'CORITechs', fmt.hdrSz=0; fmt.pixelType='uint8'; fmt.byteOrder='l'; fmt.recSz = xSz.*ySz;
          end
          mrstruct = readmr(fNames, { 'Raw', [xSz ySz zSz], fmt.pixelType, fmt.byteOrder, fmt.hdrSz, fmt.recSz}, 'NOPROGRESSBAR');
          fName = fNames{end};  % Old READMR returned last filename
        case {'Analyze7.5_SPM','DICOM_Slice','DICOM_Volume'}
          % Formats with readable headers
          mrstruct = readmr(fName, cannedFormat, 'NOPROGRESSBAR');
        case 'DICOM_AVW_VolumeFile'
          error('"DICOM_AVW_VolumeFile" format no longer supported by READMR');
        otherwise % Should never reach here.
          error(sprintf('Unknown format "%s"',cannedFormat));
      end
      % validate dimension sizes
      for i = 1:length(mrstruct.info.dimensions)
        dim = mrstruct.info.dimensions(i);
        switch dim.type
         case 'x'
          if ~isempty(xSz) & dim.size ~= xSz
            error(sprintf('Specified size for x (%d) doesn''t match calculated size (%d)', dim.size, xSz));
          end
         case 'y'
          if ~isempty(ySz) & dim.size ~= ySz
            error(sprintf('Specified size for y (%d) doesn''t match calculated size (%d)', dim.size, ySz));
          end
         case 'z'
          if ~isempty(zSz) & dim.size ~= zSz
            error(sprintf('Specified size for z (%d) doesn''t match calculated size (%d)', dim.size, zSz));
          end
        end
      end
    elseif isnumeric(argsin{5})
      % Raw/Custom format
      [hdrSz, pixelType, byteOrder, allInOne, startExt] = deal(argsin{5:end});
      fNames = {fName};
      if ~allInOne
        fNames = {};
        [pth,nm,ext]=fileparts(fName); % Strip extension
        for z=1:zSz                    % Construct filename
          fNames{z} = sprintf('%s.%03d',fullfile(pth,nm),z-1+startExt);
        end
      end
      mrstruct = readmr(fNames, { 'Raw', [xSz ySz zSz], pixelType, byteOrder, hdrSz }, 'NOPROGRESSBAR');
      fName = fNames{end};  % Old READMR returned last filename
    else
      error('Error in parsing old-style readmr arguments (arg 5 is neither a string (cannedFormat) nor a number (hdrSz)');
    end
    
    if ischar(argsin{5})
      if nargout == 1, varargout = { mrstruct.data }; end
      if nargout == 2, varargout = { mrstruct.data, fName }; end
      if nargout == 3, varargout = { mrstruct.data, fName, { xSz, ySz, zSz, cannedFormat } }; end
    elseif isnumeric(argsin{5})
      if nargout == 1, varargout = { mrstruct.data }; end
      if nargout == 2, varargout = { mrstruct.data, fName }; end
      if nargout == 3, varargout = { mrstruct.data, fName, { xSz, ySz, zSz, hdrSz, pixelType, byteOrder, allInOne, startExt } }; end
    end      
    return
  end
  %%% Done handling "old-style" readmr parameters.
  %%% end BACKWARDS-COMPATIBILITY LAYER %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  % Only allow one output argument for non-"old-style"
  if nargout > 1, error('Too many output arguments.'); end
  varargout = { struct([]) };

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% Input argument processing %%%
  
  % grab info from arguments, if exists
  if numargsin > 0
    if ischar(argsin{end})
      opts = splitstr(argsin{end}, ';');
      allmatches = [];
      curmatches = strmatch('NOPROGRESSBAR', opts, 'exact');
      if curmatches
        noprogressbar = 1;
        allmatches = [allmatches curmatches];
      end
      curmatches = strmatch('VERBOSE', opts, 'exact');
      if curmatches
        verbose = 1;
        allmatches = [allmatches curmatches];
      end
      if ~isempty(allmatches)
        % found some options
        nonmatches = setdiff([1:length(opts)], allmatches);
        if isempty(nonmatches)
          argsin(end) = [];
          numargsin = numargsin - 1;
        else
          printopts = strcat({' '}, opts(nonmatches));
          emsg = ['The following options are not recognized:' printopts{:}]; error(emsg);
        end
      end
    end
    
    if ischar(argsin{1})
      inputlocs = {argsin{1}};
    elseif iscell(argsin{1})
      inputlocs = argsin{1};
    elseif isstruct(argsin{1}) & isfield(argsin{1}, 'info') & isfield(argsin{1}, 'inputlocs')
      info = argsin{1}.info;
      if isfield(info, 'rawdimensions')
        info.dimensions = info.rawdimensions;
      end
      inputlocs = argsin{1}.inputlocs;
      inputurls = argsin{1}.inputurls;
      inputfiles = argsin{1}.inputfiles;
      downloaded = argsin{1}.downloaded;
      inputisinfo = 1;
    else
      emsg = sprintf('First argument must be filename(s) or mrinfo struct!'); error(emsg);
    end
  end
  
  % grab returnelemtype, typespec and selector from arguments
  curargnum = 2;

  if curargnum <= numargsin
    arg = argsin{curargnum};
    if (ischar(arg) & ~strncmp('=>', arg, 2)) | (iscell(arg) & ischar(arg{1}) & ~isempty(arg{1}))
      if ~isempty(info)
        emsg=sprintf('Can''t specify typespec for mrinfo input'); error(emsg);
      end
      typespec=arg;
      if ischar(typespec)
        formatname=typespec;
      else
        formatname=typespec{1};
      end
      fnum=find(strcmpi(formatname, {formats.format}));
      if isempty(fnum)
        emsg=sprintf('Can''t find typespec type "%s"',formatname); error(emsg);
      end
      mrparams=formats(fnum);
      curargnum = curargnum + 1;
    end
  end

  if curargnum <= numargsin
    arg = argsin{curargnum};
    if iscell(arg)
      selector=arg;
      curargnum = curargnum + 1;
    end
  end

  if curargnum <= numargsin
    arg = argsin{curargnum};
    if ischar(arg) & strncmp('=>', arg, 2)
      if strcmp(arg, '=>INFOONLY')
        if ~isempty(selector)
          emsg='Can''t specify data selector when in INFOONLY mode'; error(emsg);
        end
        infoonly = 1;
      elseif strcmp(arg, '=>CLEANUP')
        if ~inputisinfo
          emsg='CLEANUP requires mrinfo struct'; error(emsg);
        end
        local_deleteifintempdir(downloaded, inputlocs);
        return
      else
        argreturnelemtype = arg(3:end);
      end
      curargnum = curargnum + 1;
    end
  end

  if curargnum <= numargsin
    printargs = strcat({' '}, argsin(curargnum:end));
    emsg=['Error processing arguments:' printargs{:}]; error(emsg);
  end

  %%% Expand wildcards
  if isempty(info)
    oldinputlocs = inputlocs;
    inputlocs = {};
    inputurls = {};
    inputsizes = [];  % -1 if size has not been calculated yet.
    for i=1:length(oldinputlocs)
      loc = oldinputlocs{i};
      inputurl = filename2url(loc);
      proto = get(inputurl, 'Scheme');
      if strcmp('file', proto) & ~strncmp(loc, 'file:', 5)
        % this will expand wildcards
        if isempty(findstr(loc, '*'))
          inputlocs(end+1) = {loc};
          inputurls(end+1) = {inputurl};
          inputsizes(end+1) = -1;  % Get the size later.
        else
          newdents = dir(loc);
          if isempty(newdents),
            emsg=sprintf('No files found matching %s',loc); error(emsg);
          end
          % Sort files alphabetically since dir doesn't guarantee sorted order
          [junk,ii]=sort({newdents.name});
          newdents = newdents(ii);
          clear('junk','ii');
          pathstr = fileparts(loc);
          if ~isempty(pathstr)
            pathstr = [pathstr filesep];
          end
          newlocs = strcat(pathstr,{newdents.name});
          newurls = {};
          pwdurl = '';
          if strcmp(filesep, '/')
            pwdurl = url(['file:' pwd '/']);
          else
            pwdurl = url(['file:/' pwd filesep]);
          end
          for j=1:length(newlocs)
            newurls{j} = filename2url(newlocs{j}, pwdurl);
          end
          inputlocs(end+1:end+length(newlocs)) = newlocs;
          inputurls(end+1:end+length(newurls)) = newurls;
          inputsizes(end+1:end+length(newdents)) = [newdents.bytes];
        end
      elseif findstr(loc, '*')
        emsg = 'Wildcards (*) not allowed in URLs'; error(emsg);
      else
        inputlocs(end+1) = {loc};
        inputurls(end+1) = {inputurl};
        inputsizes(end+1) = -1;  % Get the size later.
      end
    end
  end
  
  %%% Pre-construct URLs (that haven't been constructed yet)
  if isempty(info)
    for i = length(inputurls)+1:length(inputlocs)
      inputurls{i} = filename2url(inputlocs{i});
    end
  end
  
  %%% Download URLs into local files, if needed
  if isempty(info)
    inputfiles = {};
    downloaded = {};
    [inputfiles, downloaded] = local_downloadifneeded(inputurls);
    
    %%% Figure out format of input
    
    if ~isempty(inputfiles) & ...
          (isempty(mrparams) | strcmp(mrparams.format,'Auto'))
      mrparams.format = autodetectmr(inputfiles);
    end
    
    if isempty(mrparams) | isempty(mrparams.format)
      emsg=sprintf('Can''t figure out type for file "%s"', inputlocs{1}); error(emsg);
    end
    
    % Initialize this variable even if we never use it.
    mrparams.hdr = '';
  end
  
  %%% end Input argument processing %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  

  %%%%%%%%%%%%%%%%%%%%%%
  %%% Header parsing %%%

  % At this point, the mrparams struct contains the format name,
  % and possibly some type-specific default info, too
  
  % Now fill in the rest of the mrparams struct and do some
  % type-specific validation of inputs. Most non-generic stuff
  % happens here and is abstracted away using the mrparams structure.
  % mrparams is preliminary header info, based on the struct
  % returned by readmrhdr.
  %
  % mrparams has the following fields:
  %    mrparams.format    - string from the list of supported types
  %    mrparams.hdr       - format-specific header (for writing)
  %    mrparams.matSz     - dimensions of the data
  %    mrparams.hdrSz     - size of header(s) (multiple values for DICOM)
  %    mrparams.recSz     - size of record to read (may have multiple values)
  %    mrparams.pixelType - 'int32', 'uint16', etc.
  %    mrparams.byteOrder - 'b'==big-endian, 'l'==little-endian, etc.
  %    mrparams.dimorder  - cell array of dimension names in data order
  %    mrparams.units     - cell array of units in dimension order
  %    mrparams.origin    - location of first element in RAS coordinates
  %    mrparams.direction - cell array of direction vectors of dimensions
  %    mrparams.gap       - gaps between elements along each dimension
  %    mrparams.voxSz     - sizes of voxels in each dimension
  
  if isempty(info)
    if verbose
      disp(['Parsing file(s) of type "' mrparams.format '"']);
    end
    switch mrparams.format
     case 'BXH'
      %% --- BIAC XML Header ---
      if length(inputlocs) > 1
        emsg='Multiple BXH input files makes no sense!'; error(emsg);
      end
      bxh = readbxhhdr(inputfiles{1});
      datarecs = bxh.bxh{1}.datarec;
      bxhtype = [];
      bxhsubtype = [];
      if iscell(typespec)
        if length(typespec) > 3 | ...
              (length(typespec) >= 2 & ~ischar(typespec{2})) | ...
              (length(typespec) == 3 & ~ischar(typespec{3}))
          emsg='Invalid typespec! ''BXH'' must have the following format: {''BXH'', type[, subtype] }'; error(emsg);
        end
        if length(typespec) >= 2
          bxhtype = typespec{2};
        end
        if length(typespec) == 3
          bxhsubtype = typespec{3};
        end
      else
        bxhtype = 'image';
      end
      for datarecnum=1:length(datarecs)
        datarec = datarecs{datarecnum};
        if ((isempty(bxhtype) | ...
             (isfield(datarec, 'ATTRS') & ...
              isfield(datarec.ATTRS, 'type') & ...
              strcmp(datarec.ATTRS.type.VALUE, bxhtype))) & ...
            (isempty(bxhsubtype) | ...
             (isfield(datarec.ATTRS, 'subtype') & ...
              strcmp(datarec.ATTRS.subtype.VALUE, bxhsubtype))))
          if ~isempty(info)
            emsg=sprintf('BXH type/subtype "%s"/"%s" matches more than one datarec!', bxhtype, bxhsubtype); error(emsg);
          end
          info = datarec2mrinfo(datarec);
          info.basepath = inputurls{1};
          break
        end
      end
      if isempty(info)
        emsg=sprintf('Can''t find datarec type/subtype "%s"/"%s" in BXH file!', bxhtype, bxhsubtype); error(emsg);
      end
      info.hdr = bxh;
      info.hdr.bxh{1} = rmfield(info.hdr.bxh{1}, 'datarec');
      info.hdrtype = mrparams.format;
      info.hdr.BASE = info.basepath;
     
     
     case { 'DICOM_Slice', 'DICOM_Volume', 'DICOM', 'DICOM_Search' }
      %% --- DICOM ---
      [flag,msg]=isdicom(inputfiles{1});
      if ~flag, emsg=msg; error(emsg); end
      dictionary = [];
      if iscell(typespec) & length(typespec) > 1
        if ~ischar(typespec{2})
          emsg='Invalid typespec! ''DICOM'' must have the following format: {''DICOM''[, dictionary] }'; error(emsg);
        end
        % { 'DICOM_*', dictionary }
        dictionary = typespec{2};
      end
      
      if length(inputfiles) > 1 & strcmp(mrparams.format, 'DICOM_Slice')
        emsg='DICOM_Slice only accepts one filename!'; error(emsg);
      end
      if length(inputfiles) > 1 & strcmp(mrparams.format, 'DICOM_Search')
        emsg='DICOM_Search only accepts one filename!'; error(emsg);
      end
      if strcmp(mrparams.format, 'DICOM_Search') & ~isempty(downloaded{1})
        emsg='DICOM_Search cannot be used on remote files!'; error(emsg);
      end
      % see if we should search for other files
      searchforothers = 1;
      if strcmp(mrparams.format, 'DICOM')
        % don't search -- just use what's given
        searchforothers = 0;
      elseif strcmp(mrparams.format, 'DICOM_Slice')
        % don't search -- explicitly a slice
        searchforothers = 0;
      elseif ~isequal(downloaded, repmat({[]}, [1 length(downloaded)]))
        % don't search -- at least one remote file
        searchforothers = 0;
      elseif length(inputfiles) > 1
        % don't search -- multiple files in file list
        searchforothers = 0;
      end
      % because this is so complicated, push all the smarts into 
      % local helper function
      [info,inputfiles,inputlocs,inputsizes] = local_dicom2mrinfo(inputfiles,inputlocs,inputsizes,dictionary,searchforothers);
      
     case 'Float'
      % { 'Float', dimsizes }
      % Check typespec format
      if ~iscell(typespec) | length(typespec) ~= 2
        emsg='Invalid typespec! ''Float'' must have the following format: {''Float'',dimsizes}'; error(emsg);
      end
      if ~isnumeric(typespec{2}) | ndims(typespec{2}) ~=2 | ...
            min(size(typespec{2})) ~= 1 | any(~isint(typespec{2})) | any(typespec{2}<1)
        emsg='Invalid typespec! dimsizes must be a vector of positive integers!'; error(emsg);
      end
      % Extract mrparams from typespec
      mrparams.matSz = typespec{2};
      % If input only has 3 dimensions, number of files is size of 4th
      if length(mrparams.matSz) == 3
        mrparams.matSz(4) = length(inputlocs);
      end
      
     case 'Volume'
      % { 'Volume', dimsizes }
      % Check typespec format
      if ~iscell(typespec) & length(typespec) ~= 2
        emsg='Invalid typespec! ''Volume'' must have the following format: {''Volume'',dimsizes}'; error(emsg);
      end
      if ~isnumeric(typespec{2}) | ndims(typespec{2}) ~=2 | ...
            min(size(typespec{2})) ~= 1 | any(~isint(typespec{2})) | any(typespec{2}<1)
        emsg='Invalid typespec! dimsizes must be a vector of positive integers!'; error(emsg);
      end
      % Extract mrparams from typespec
      mrparams.matSz = typespec{2};
      % If input only has 3 dimensions, number of files is size of 4th
      if length(mrparams.matSz) == 3
        mrparams.matSz(4) = length(inputlocs);
      end
     
     case 'Raw'
      % { 'Raw', dimsizes, pixelType, byteOrder, hdrSz, opt_recSz, opt_dimorder }
      % Check typespec format
      if ~iscell(typespec) | all(length(typespec) ~= [5,6,7])
        emsg='Invalid typespec! Incorrect number of typespec parameters for ''Raw'' format'; error(emsg);
      end
      if ~isnumeric(typespec{2}) | ndims(typespec{2}) ~=2 | ...
            min(size(typespec{2})) ~= 1 | any(~isint(typespec{2})) | any(typespec{2}<1)
        emsg='Invalid typespec! dimsizes must be a vector of positive integers!'; error(emsg);
      end
      if ~ischar(typespec{3})
        emsg='Invalid typespec! pixelType must be a string!'; error(emsg);
      end
      if ~ischar(typespec{4})
        emsg='Invalid typespec! byteOrder must be a string!'; error(emsg);
      end
      if ~isnumeric(typespec{5}) | any(size(typespec{5})~=1) | ...
            ~isint(typespec{5}) | any(typespec{5}<0)
        emsg='Invalid typespec! hdrSz must be a positive scalar'; error(emsg);
      end
      if length(typespec) > 5 & ~isnumeric(typespec{6})
        emsg='Invalid typespec! opt_recSz must be numeric!'; error(emsg);
      end
      if length(typespec) > 6 & ~iscellstr(typespec{7})
        emsg='Invalid typespec! opt_dimorder must be a cell array of strings!'; error(emsg);
      end
      % Extract mrparams from typespec
      [ mrparams.format, mrparams.matSz, ...
        mrparams.pixelType, mrparams.byteOrder, ...
        mrparams.hdrSz ] = deal(typespec{1:5});
      if length(typespec) > 5
        mrparams.recSz = typespec{6};
        if mrparams.recSz ~= Inf
          [inputsizes] = deal(mrparams.hdrSz + mrparams.recSz);
        end
      else
        mrparams.recSz = Inf;
      end
      if length(typespec) > 6
        mrparams.dimorder = typespec{7};
        if ~isempty(mrparams.dimorder) & length(mrparams.dimorder) ~= length(mrparams.matSz)
          emsg='Invalid typespec! number of dimensions in opt_dimorder and dimsizes does not match!'; error(emsg);
        end
      end
    
     otherwise
      % Not BXH, DICOM etc. -- just use readmrhdr

      % first download .img for Analyze if needed
      if strcmp(mrparams.format, 'Analyze7.5_SPM')
        if ~isempty(downloaded{1})
          extstart = [];
          if length(inputlocs{1}) >= length('.hdr')
            extstart = findstr(inputlocs{1}, '.hdr');
          end
          newloc = [inputlocs{1}(1:extstart) 'img'];
          extstart = [];
          if length(inputfiles{1}) >= length('.hdr')
            extstart = findstr(inputfiles{1}, '.hdr');
          end
          newfilename = [inputfiles{1}(1:extstart) 'img'];
          if exist(newfilename, 'file')
            error('Error finding temporary file name for downloading Analyze .img');
          end
          newurl = filename2url(newloc);
          [newinputfiles, newdownloaded] = local_downloadifneeded({newurl});
          [status, emsg] = movefile(newinputfiles{1}, newfilename);
          if status == 0, error(emsg); end
          inputlocs{2} = newloc;
          inputurls{2} = newurl;
          inputfiles{2} = newfilename;
          downloaded{2} = newfilename;
        end
      end
      
      [newparams,emsg] = readmrhdr(inputfiles{1}, mrparams.format);
      if ~isempty(emsg), error(emsg); end
      if strcmp(mrparams.format, 'Signa5') | strcmp(mrparams.format, 'SignaXIMG')
        % Fix Z in case we are given fewer files
        newparams.matSz(3) = length(inputlocs);
      end
      
      mrparams.matSz = newparams.matSz;
      mrparams.hdrSz = newparams.hdrSz;
      mrparams.recSz = Inf;
      mrparams.pixelType = newparams.pixelType;
      mrparams.byteOrder = newparams.byteOrder;
      if isfield(newparams, 'origin')
        mrparams.origin = newparams.origin;
      end
      if isfield(newparams, 'voxSz')
        mrparams.voxSz = newparams.voxSz;
      end
      % Put multiple input files in 4th dimension for Analyze7.5_SPM
      if strcmp(mrparams.format,'Analyze7.5_SPM') & length(inputlocs) > 1
        if length(newparams.matSz) ~= 3
          emsg = sprintf('Can''t read multiple 4-D Analyze files!'); error(emsg);
        end
        mrparams.matSz(4) = length(inputlocs);
        % Use NaN for origin and voxSz 4th dimension since header does
        % not contain this information.
        mrparams.origin(4) = NaN;
        mrparams.voxSz(4) = NaN;
      end
    end
  end
  
  % Save the "raw" header for those formats who haven't done it already
  if isempty(info) & isempty(mrparams.hdr) & mrparams.hdrSz > 0
    [fid, emsg] = fopen(inputfiles{1}, 'r');
    if fid==-1, emsg=msg; error(emsg); end
    [mrparams.hdr, count] = fread(fid, mrparams.hdrSz, 'uchar=>uchar');
    if count ~= mrparams.hdrSz
      fclose(fid);
      emsg = sprintf('Can''t read enough bytes in header for file %s!', inputlocs{1}); error(emsg);
    end
    fclose(fid);
  end
  
  %%% end Header parsing %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% Construct internal data descriptor (info) %%%

  % Construct info structure using mrparams struct and info in files
  % themselves.  The info structure will be used to stage subsequent
  % data reads.  Unless otherwise specified, the info structure describes
  % the data as it exists in the external files/frags if INFOONLY, or the
  % data to be returned otherwise.
  %  These fields are returned in the info struct:
  %     info.elemtype   - type of the in-memory data, 'uint16', 'float32',
  %                       etc. to be returned (i.e. as mrstruct.data)
  %     info.outputelemtype - data type to use if writing the data.
  %     info.byteorder  - 'b'==big-endian, 'l'==little-endian
  %     info.dimensions - array of dimension structs describing the
  %                       dimensionality of the data when returned (see below)
  %     info.hdr        - format-specific header (for writing)
  %     info.hdrtype    - type of header
  %     info.displayname - name of input file (informational only)
  %   dimension struct:
  %     dim.type      - name of dimension ('x', 't', etc.)
  %     dim.units     - 'mm', 'ms', etc.
  %     dim.size      - size of this dimension
  %     dim.outputselect - for output, select only these elements, indexed
  %                        after merging split dimensions.
  %     dim.origin    - R, A, or S coordinate (depending on orientation)
  %     dim.gap       - unsampled space between elements
  %     dim.spacing   - distance between element centers in this dimension
  %     dim.direction - RAS vector in which this dimension 
  %
  %  These fields are used internally (returned only if INFOONLY):
  %     info.frags         - a fragment list struct (see below)
  %     info.basepath      - context path in which relative pathnames
  %                           are interpreted (current directory if empty) 
  %     info.rawelemtype   - type of data, 'uint16', 'float32', etc. on disk
  %     info.rawdimensions - the dimensions of the data on disk
  %     info.inputselector - input selector array, but in data order
  %  These fields are also used internally for "split" dimensions
  %  and "outputselect" dimensions (returned only if INFOONLY).
  %  See notes below in the 'Deal with "split" and "outputselect"
  %  dimensions' section:
  %     info.permute        - this will permute the returned data
  %     info.permdimdeleteinds  - this will delete these permuted dimensions
  %     info.inputreshape   - this will reshape the returned data
  %     info.outputselector - this will select portions of the output
  %     info.outputreshape  - this will reshape the returned data
  %   fragment list struct (N frags represented by three arrays of N elements):
  %     frag.filenames   - cell array of N filenames
  %     frag.fileoffsets - vector containing a file offset for each frag
  %     frag.fragsizes   - vector containing length of each fragment
  %
  
  if isempty(info)
    % do easy fields
    info.rawelemtype = mrparams.pixelType;
    info.outputelemtype = mrparams.pixelType;
    info.elemtype = 'float64';
    typesize = typesizes(find(strcmp(mrparams.pixelType,{typesizes.type})));
    elemsize = typesize.size;
    info.byteorder = mrparams.byteOrder;
    info.hdr = mrparams.hdr;
    info.hdrtype = mrparams.format;
    % do dimensions
    numdims = length(mrparams.matSz);
    if ~isfield(mrparams, 'dimorder') | isempty(mrparams.dimorder)
      mrparams.dimorder = { 'x', 'y', 'z', 't' };
      mrparams.dimorder = mrparams.dimorder(1:numdims);
    end
    if ~isfield(mrparams, 'units') | isempty(mrparams.units)
      mrparams.units = mrparams.dimorder;
      for i=1:length(mrparams.units)
        % XXX add format-specific changes below
        switch mrparams.units{i}
          case 'x', mrparams.units{i}='';
          case 'y', mrparams.units{i}='';
          case 'z', mrparams.units{i}='';
          case 't', mrparams.units{i}='';
          otherwise, mrparams.units{i}='';
        end
      end
    end
    % Handle matrix size
    mrparams.matSz = num2cell(mrparams.matSz);
    % Handle origin (NaN by default)
    if ~isfield(mrparams, 'origin') | isempty(mrparams.origin)
      mrparams.origin = repmat({NaN},[1,numdims]);
    elseif ~iscell(mrparams.origin)
      mrparams.origin = num2cell(mrparams.origin);
    end
    % Handle gap (NaN by default)
    if ~isfield(mrparams, 'gap') | isempty(mrparams.gap)
      mrparams.gap = repmat({NaN},[1,numdims]);
    elseif ~iscell(mrparams.gap)
      mrparams.gap = num2cell(mrparams.gap);
    end
    % Handle voxel size (NaN by default)
    if ~isfield(mrparams, 'voxSz') | isempty(mrparams.voxSz)
      mrparams.voxSz = repmat({NaN},[1,numdims]);
    elseif ~iscell(mrparams.voxSz)
      mrparams.voxSz = num2cell(mrparams.voxSz);
    end
    % Handle direction vector ([NaN NaN NaN] by default)
    if ~isfield(mrparams, 'direction') | isempty(mrparams.direction)
      mrparams.direction = repmat({[NaN NaN NaN]},[1,numdims]);
    end
    % Handle direction precision (NaN by default)
    if ~isfield(mrparams, 'directionprecision') | isempty(mrparams.directionprecision)
      mrparams.directionprecision = repmat({NaN},[1,numdims]);
    end
    info.dimensions = struct( ...
      'type', mrparams.dimorder, ...
      'units', mrparams.units, ...
      'size', mrparams.matSz, ...
      'outputselect', NaN, ...
      'origin', mrparams.origin, ...
      'spacing', mrparams.voxSz, ...
      'gap', mrparams.gap, ...
      'datapoints', {{NaN}}, ...
      'direction', mrparams.direction, ...
      'directionprecision', mrparams.directionprecision);
    info.basepath = '';

    % do frags
    if strcmp(mrparams.format, 'Analyze7.5_SPM')
      for i = 1:length(inputlocs)
        extstart = [];
        if length(inputlocs{i}) >= length('.hdr')
          extstart = findstr(inputlocs{i}, '.hdr');
        end
        if ~isempty(extstart) & extstart(end) == length(inputlocs{i}) - 3
          % don't need .hdr anymore -- get rid of it and use .img
          if ~isempty(downloaded{i})
            local_deleteifintempdir({downloaded{i}}, {inputlocs{i}});
          end
          inputlocs{i} = [inputlocs{i}(1:extstart-1) '.img'];
          inputurls{i} = filename2url(inputlocs{i});
          [newinput, newdownload] = local_downloadifneeded({inputurls{i}});
          inputfiles{i} = newinput{1};
          downloaded{i} = newdownload{1};
          % need to get sizes of the .img files
          inputsizes(i) = -1;
        end
      end
    end
    
    % Determine inputsizes that have not been calculated yet.
    ii = find(inputsizes == -1);
    if ~isempty(ii)
      inputsizes(ii) = local_getfilesizes(inputfiles(ii));
    end
    
    if strcmp(mrparams.format, 'Volume') | strcmp(mrparams.format, 'Float')
      % Require that Volume and Float formats have equal sized files and read the entire file
      % (to avoid errors from typing in the wrong number of slices or wrong format)          
      fragsizes = inputsizes; % Use whole file
      expectedSize = prod([info.dimensions(1:3).size]).*elemsize;
      if any(diff(fragsizes)~=0)
        error('All files must be the same size for Volume and Float formats!');
      elseif any(fragsizes < expectedSize)
        error(sprintf('Not enough data in file %s',inputlocs{1}));
      elseif any(fragsizes > expectedSize)
        error(sprintf('More data remaining in file %s',inputlocs{1}));
      end
    elseif ~isempty(mrparams.recSz) & ~isinf(mrparams.recSz)
      fragsizes = mrparams.recSz;
    else
      fragsizes = inputsizes - mrparams.hdrSz; % Use whole file minus header
    end
    info.frags = [];
    info.frags.filenames = inputfiles;
    info.frags.fileoffsets = repmat(mrparams.hdrSz,[1 length(inputfiles)]);
    info.frags.fragsizes = fragsizes;

    % Clean up some variables so that we don't use them later.
    clear('mrparams')
  end
  
  if ~isempty(inputlocs) & ischar(inputlocs{1})
    info.displayname = inputlocs{1};
  else
    info.displayname = '';
  end

  if ~isfield(info, 'elemtype') | isempty(info.elemtype)
    info.elemtype = 'float64';
  end
  %%% If argreturnelemtype is =>native, use the native element type (from info)
  if ~isempty(argreturnelemtype) & strcmp(argreturnelemtype,'native')
    argreturnelemtype = info.rawelemtype;
  end
  if ~isempty(argreturnelemtype)
    info.elemtype = argreturnelemtype;
    info.outputelemtype = argreturnelemtype;
  end
  clear('argreturnelemtype');
  
  % save old dimensions in case we permute on return
  info.rawdimensions = info.dimensions;
  
  if verbose
    disp(['Dimensions of raw data: [' cell2mat(strcat({' '}, num2str([info.rawdimensions.size]))) ' ]']);
  end

  %%% end Construct internal data descriptor %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% Deal with "split" and "outputselect" dimensions %%%
  %
  % "Split" dimensions are two or more dimensions that need to
  % be merged into one before returning the data.  This is used,
  % for example, to describe data that is tiled (like the mosaic
  % format used in Siemens DICOM), e.g. the z-dimension is
  % conceptually split into x- and y-tiled dimensions.
  % The data returned by readmr needs to reflect the merged,
  % reshaped, and permuted (if needed) dimensions.
  % Because the returned mrstruct.info.dimensions must accurately
  % reflect the returned data (mrstruct.data), it will need
  % to be modified too -- but the on-disk data dimensions will
  % be stored in info.rawdimensions.
  %
  % "Outputselect" dimensions are those for which some number
  % of datapoints need to be ignored before the data is
  % presented to the user.  This selection process is applied
  % after "split" dimensions are merged and permuted, so can
  % only appear in the last component dimension of a split dimension.
  % This is used, for example, to ignore blank slices that
  % occur in Siemens mosaic DICOM images.  As above, the dimensions
  % field will be updated to reflect the new size of the dimension,
  % but the rawdimensions field will contain the unaltered dimension
  % structs.
  %
  % If we encounter split or outputselect dimensions, we store
  % enough info to be able to collate/permute/select the dimensions
  % and data after we reading the data from disk.  This info will be
  % cached in the info struct if you call '=>INFOONLY' if you want
  % to see them, but will be recalculated anyway from the rawdimensions
  % field each time you call readmr.  The following fields may be
  % kept in the info struct if there are split dimensions or
  % outputselect attributes in any dimension:
  %  info.permute -
  %    list of indices, indicating how to reorder the raw data and
  %    dimensions to make split dimensions adjacent and in-order.
  %  info.permdimdeleteinds -
  %    list of dimension indices, after permutation, of those
  %    dimensions that should be deleted (all but the last component
  %    of each split dimension).
  %  info.inputnewsizes -
  %    dimensionality of the data after permutation and merging of
  %    split dimensions.
  %  info.outputselector -
  %    filters for each dimension based on outputselect attributes.
  %  info.outputnewsizes -
  %    dimensionality of the data after running through outputselect
  %    filters (and previous permutation/merging of split dimensions).
  % These fields are cleared before return if we return actual data
  % (i.e. not =>INFOONLY)
  %
  % After these fields are filled in, the effective order of operations
  % when reading data is as follows:
  % 0) Data is assumed to already be filtered using info.inputselector.
  % 1) Permute the data and info.dimensions using info.permute.
  %    Split dimensions are now adjacent.
  % 2) Delete those dimensions in info.dimensions listed in
  %    info.permdimdeleteinds.
  % 3) Reshape the data using info.inputnewsizes, and modify the sizes
  %    in info.dimensions to match.  Split dimensions are now fully
  %    merged.
  % 4) Filter the data using the selectors in info.outputselector.
  % 5) Modify the sizes in info.dimensions using info.outputnewsizes.
  %    Data and dimensions are now fully permuted/merged/filtered.
  %
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% Deal with "split" dimensions %%%
  
  % order "special" dimensions to be in the canonical order
  % by setting info.permute and info.permdimdeleteinds.
  % also remove the '-splitN' suffix from the name of the last
  % split dimension.

  movethese = [];
  mergeinto = [1:length(info.dimensions)];
  deletethese = zeros(1,length(info.dimensions));
  for dimnamecell={'x', 'y', 'z', 't'}
    dimname = dimnamecell{1};
    spname = [dimname '-split'];
    exinds = strmatch(dimname, {info.dimensions.type}, 'exact');
    spinds = strmatch(spname, {info.dimensions.type});
    if ~isempty(exinds)
      movethese = [movethese exinds'];
    elseif ~isempty(spinds)
      spnums = [];
      for spind=1:length(spinds)
        spnumstr = info.dimensions(spinds(spind)).type(length(spname)+1:end);
        spnums(spind) = str2double(spnumstr);
        info.dimensions(spinds(spind)).type = dimname;
      end
      [sorted, sortinds] = sort(spnums);
      movethese = [movethese spinds(sortinds)'];
      for i=1:length(sortinds)
        if i < length(sortinds)
          deletethese(spinds(sortinds(i))) = 1;
        end
        mergeinto(spinds(sortinds(i))) = spinds(sortinds(end));
      end
    end
  end
  if ~isempty(movethese) & any(movethese ~= [1:length(movethese)])
    dontmovethese = setdiff([1:length(info.dimensions)], movethese);
    info.permute = [movethese dontmovethese];
    info.permdimdeleteinds = find(deletethese(info.permute));
  end

  %%% end Deal with "split" dimensions %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% Create input and output selectors %%%
  
  % The selector arrays are ways to ignore portions of the data.
  % These are created in response to an explicit selector argument
  % or due to 'outputselect' attributes in dimensions.
  % Selection can be performed at two points, once before actually
  % reading any data (input selectors), and after reading/permuting the
  % data (output selectors).  When possible, input selectors are preferred
  % because we can try to avoid reading extraneous data.  However,
  % selectors for split dimensions can't always be described in
  % terms of selectors for the component dimensions, so in some
  % cases these are forced to be output selectors.
  
  info.inputselector = {};
  info.outputselector = {};

  for dimnum=1:length(info.dimensions)
    info.inputselector{dimnum} = [1:info.dimensions(dimnum).size];
    info.outputselector{dimnum} = [];
  end

  % Create initial outputselect array from "outputselect" dimensions.
  % Create it in input order (i.e. before permutation) for now.
  if isfield(info.dimensions, 'outputselect')
    info.outputselector = {};
    sizes = [info.dimensions.size];
    for dimnum=1:length(info.dimensions)
      info.outputselector{dimnum} = info.dimensions(dimnum).outputselect;
      if isempty(info.outputselector{dimnum}) | isnan(info.outputselector{dimnum})
        info.outputselector{dimnum} = [];
      end
    end
  end
  
  if ~isempty(selector)
    sizes = [info.dimensions.size];
    if length(selector) < 4, [selector{length(selector)+1:4}] = deal([]); end
    extradims = 0;
    for dimnum=1:length(info.dimensions)
      dimtype = info.dimensions(dimnum).type;
      if strcmp(dimtype, 'x')
        curselect = selector{1};
      elseif strcmp(dimtype, 'y')
        curselect = selector{2};
      elseif strcmp(dimtype, 'z')
        curselect = selector{3};
      elseif strcmp(dimtype, 't')
        curselect = selector{4};
      else
        if length(selector) >= 4 + extradims + 1
          curselect = selector{4+extradims+1}; 
        else
          curselect = [];
        end
        extradims = extradims + 1;
      end
      issplit = 0;
      if length(find(mergeinto == mergeinto(dimnum))) > 1
        issplit = 1;
      end
      if issplit & mergeinto(dimnum) ~= dimnum
        % not last split dimension, so ignore
        curselect = [];
      end
      
      % sanity checks
      if ~isempty(curselect)
        sortedcurselect = sort(curselect);
        if sortedcurselect ~= curselect
          emsg='Selector indices must be in increasing order!'; error(emsg);
        end
        if sortedcurselect(1) <= 0
          emsg='Selector indices must be non-negative!'; error(emsg);
        end
        if find(diff(sortedcurselect) == 0) > 0
          emsg='Selector indices must not be repeated!'; error(emsg);
        end
        dimsize = prod([info.dimensions(find(mergeinto == dimnum)).size]);
        if ~isempty(info.outputselector{dimnum})
          if sortedcurselect(end) > length(info.outputselector{dimnum})
            emsg=sprintf('Selector index %d too high for dimension "%s"!', sortedcurselect(end), dimtype(1)); error(emsg);
          end
        elseif sortedcurselect(end) > dimsize
          emsg=sprintf('Selector index %d too high for dimension "%s"!', sortedcurselect(end), dimtype); error(emsg);
        end
      end

      if ~isempty(curselect) & issplit
        % move selector to output selector
        if ~isempty(info.outputselector) & ~isempty(info.outputselector{dimnum})
          % update output selector to focus only on current selector
          info.outputselector{dimnum} = info.outputselector{dimnum}(curselect);
        else
          info.outputselector{dimnum} = curselect;
        end
        curselect = [];
      end
      
      if isempty(curselect)
        curselect = [1:sizes(dimnum)];
      end
      
      info.inputselector{dimnum} = curselect;
    end
  end
  
  for dimnum=1:length(info.outputselector)
    if isempty(info.outputselector{dimnum})
      % Works even if dimension is not a split dimension.
      % Split dimensions that will be deleted later will have a
      % selector of size 1 ([1]).
      mergedsize = 1;
      splits = find(mergeinto == mergeinto(dimnum));
      for split=splits
        mergedsize = mergedsize * length(info.inputselector{split});
      end
      info.outputselector{dimnum} = [1:mergedsize];
    end
  end

  if isempty(info.outputselector)
    info = rmfield(info, 'outputselector');
  else
    remove = 1;
    for dimnum=1:length(info.outputselector)
      if length(info.outputselector{dimnum}) ~= length(info.inputselector{dimnum})
        remove = 0;
      end
    end
    if remove
      info = rmfield(info, 'outputselector');
    end
  end
  if isempty(info.inputselector)
    info = rmfield(info, 'inputselector');
  else
    remove = 1;
    sizes = [info.dimensions.size];
    for dimnum=1:length(info.inputselector)
      if length(info.inputselector{dimnum}) ~= sizes(dimnum)
        remove = 0;
      end
    end
    if remove
      info = rmfield(info, 'inputselector');
    else
      if verbose
        disp('Input selector:');
        for dimnum=1:length(info.inputselector)
          curselect = info.inputselector{dimnum};
          strs = splitstr(num2str(curselect), ' ')';
          if isempty(find(diff(curselect) ~= 1))
            disp([info.dimensions(dimnum).type ': [ ' strs{1} ':' strs{end} ' ]']);
          else
            disp([info.dimensions(dimnum).type ': [' cell2mat(strcat({' '}, strs)) ' ]']);
          end
        end
      end
    end
  end

  if verbose
    if isfield(info, 'permute')
      disp(['Returned data will be permuted: [' cell2mat(strcat({' '}, {info.dimensions(info.permute).type})) ' ]']);
    end
    if isfield(info, 'permdimdeleteinds')
      disp(['These dimensions will then be deleted: [' cell2mat(strcat({' '}, num2str(info.permdimdeleteinds))) ' ]']);
    end
  end

  if isfield(info, 'outputselector')
    % rearrange outputselector to be in output order
    if isfield(info, 'permute')
      permkeepinds = setdiff([1:length(info.dimensions)], info.permdimdeleteinds);
      info.outputselector = info.outputselector(info.permute);
      info.outputselector = info.outputselector(permkeepinds);
    end
    if verbose
      disp('Output selector:');
      newdims = info.dimensions;
      if isfield(info, 'permute')
        permkeepinds = setdiff([1:length(info.dimensions)], info.permdimdeleteinds);
        newdims = newdims(info.permute);
        newdims = newdims(permkeepinds);
      end
      for outdimnum=1:length(newdims)
        curselect = info.outputselector{outdimnum};
        strs = splitstr(num2str(curselect), ' ')';
        if isempty(find(diff(curselect) ~= 1))
          disp([newdims(outdimnum).type ': [ ' strs{1} ':' strs{end} ' ]']);
        else
          disp([newdims(outdimnum).type ': [' cell2mat(strcat({' '}, strs)) ' ]']);
        end
      end
    end
  end

  %%% end Create input and output selectors %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Calculate 'newsizes' fields (based on input and output selectors)
  if isfield(info, 'permute')
    newsizes = [info.dimensions.size];
    if isfield(info, 'inputselector')
      for i=1:length(newsizes)
        if ~isempty(info.inputselector{i})
          newsizes(i) = length(info.inputselector{i});
        end
      end
    end
    % newsizes is in input order, convert it to output order
    info.inputnewsizes = newsizes;
    for fromind=1:length(mergeinto)
      intoind = mergeinto(fromind);
      if intoind == fromind, continue; end
      info.inputnewsizes(intoind) = info.inputnewsizes(intoind) * info.inputnewsizes(fromind);
    end
    permkeepinds = setdiff([1:length(info.dimensions)], info.permdimdeleteinds);
    info.inputnewsizes = info.inputnewsizes(info.permute);
    info.inputnewsizes = info.inputnewsizes(permkeepinds);
  end
  if isfield(info, 'outputselector')
    newsizes = [];
    for i=1:length(info.outputselector)
      newsizes(i) = length(info.outputselector{i});
    end
    info.outputnewsizes = newsizes;
  end

  
  %%%%%%%%%%%%%%%%%%
  %%% =>INFOONLY %%%

  %%% short-circuit here if INFOONLY
  if infoonly
    % Permute dimensions if needed (need to correspond to whatever
    % the resulting data will look like)
    if isfield(info, 'permute') & ~isempty(info.permute)
      info.dimensions = info.dimensions(info.permute);
      permkeepinds = setdiff([1:length(info.dimensions)], info.permdimdeleteinds);
      info.dimensions = [info.dimensions(permkeepinds)];
    end
    if isfield(info, 'outputnewsizes')
      cellsizes = num2cell(info.outputnewsizes);
    else
      cellsizes = num2cell([info.dimensions.size]);
    end
    [info.dimensions.size] = deal(cellsizes{:});
    varargout{1} = struct('info', {info}, 'inputlocs', {inputlocs}, 'inputurls', {inputurls}, 'inputfiles', {inputfiles}, 'downloaded', {downloaded});
    return
  end

  %%% end =>INFOONLY %%%
  %%%%%%%%%%%%%%%%%%%%%%

  %%%%%%%%%%%%%%%%%
  %%% Read data %%%

  if isempty(srs)
    if isfield(info, 'inputselector')
      orderedselect = info.inputselector;
    else
      orderedselect = {};
      [orderedselect{1:length(info.dimensions)}] = deal([]);
    end
    
    numdims = length(info.dimensions);
    sizes = [info.dimensions.size];
    fragsizes = info.frags.fragsizes;
    fragstarts = cumsum([0 fragsizes(1:end-1)]);
    fragends = cumsum(fragsizes);
    totaldatasize = sum(fragsizes);
    orderedselect{numdims+1} = [1]; % sentry
    
    typesize = typesizes(find(strcmp(info.rawelemtype,{typesizes.type})));
    elemsize = typesize.size;

    % Double-check that input sizes match with size of file data
    if totaldatasize ~= prod(sizes) * elemsize
      emsg = 'Input size array doesn''t match size of data!'; error(emsg);
    end
    
    % Calculate size of end result (based on selector)
    newsizes = sizes;
    for i=1:length(sizes)
      if ~isempty(orderedselect{i})
        newsizes(i) = length(orderedselect{i});
      end
    end
    
    % array of those dimensions that select portions of data
    selecteddims = find(sizes ~= newsizes);
    if isempty(selecteddims), selecteddims = numdims + 1; end
    
    % We look at each dimension as a "book" of "pages", where each
    % page contains all data in the smaller/faster dimensions for
    % each datapoint in the dimension.  The purpose of the selector
    % array is to specify which pages in each dimension to keep.
    % We determine the page size of the fastest dimension that has
    % values in the selector array, and iterate through the data
    % at that granularity, checking the per-dimension "coordinates"
    % of each page to see if it matches in the selector array.
    
    % Sometimes the size of contiguous ranges might be too small to be
    % read efficiently from files (due either to Matlab or file tranfer
    % speed).  We use a heuristic to determine when to move up a dimension
    % and read larger pages.  Currently, we try to make the unread chunks
    % have an average size larger than this:
    minunreadchunksize = 2^10; % 1KB
    % and the read chunks have an average size at most:
    maxreadchunksize = 2^20; % 1MB
    % NOTE: Contiguous pages from the same file are always read in
    % one chunk.  So for purposes of the above heuristics, we
    % calculate the number of contiguous page ranges (chunks).
    
    % If we decide to read larger pages, we do so by increasing
    % the base page size granularity by one or more dimensions,
    % and delaying the finer-granularity selection from the skipped
    % dimensions until after the disk read (selector elements moved
    % to postselect array).
    
    postselect = {};
    basepagedim = 0;
    numchunks = 0;
    dochunk = 0;
    totalreadsize = 0;
    
    % pre-calculate number of contiguous chunks per dimension
    % by finding number of contiguous page ranges in selection
    % vector.
    % Contiguous ranges start with a difference > 1 from the
    % last element, and end with a difference > 1 to the next element
    unreadchunksperdim = ones(1, numdims+1);
    readchunksperdim = ones(1, numdims+1);
    for i = 1:length(selecteddims)
      d = selecteddims(i);
      if d <= numdims
        % The 0 is to trigger the first unread chunk if it is flush left
        % and (sizes(d)+1) triggers the last unread chunk if it is flush right
        unreadchunksperdim(d) = sum(diff([0 orderedselect{d} (sizes(d)+1)])>1);
        % The -1 is to trigger the first read chunk if it is flush left
        readchunksperdim(d) = sum(diff([-1 orderedselect{d}])>1);
      end
    end

    % start off at fastest "selected" dimension
    basepagedim = selecteddims(1);
    totalreadsize = elemsize * prod(sizes(1:basepagedim-1)) * prod(newsizes(basepagedim:numdims));
    numunreadchunks = unreadchunksperdim(basepagedim) * prod(sizes(basepagedim+1:numdims));
    avgunreadchunksize = totalreadsize / numunreadchunks;
    numreadchunks = readchunksperdim(basepagedim) * prod(sizes(basepagedim+1:numdims));
    avgreadchunksize = totalreadsize / numreadchunks;
    while basepagedim <= numdims & ...
          avgunreadchunksize < minunreadchunksize & ...
          avgreadchunksize < maxreadchunksize
      dochunk = 1;
      % want to chunk larger than current page size -- go up one
      % more dimension
      basepagedim = basepagedim + 1;
      totalreadsize = elemsize * prod(sizes(1:basepagedim-1)) * prod(newsizes(basepagedim:numdims));
      numunreadchunks = unreadchunksperdim(basepagedim) * prod(sizes(basepagedim+1:numdims));
      avgunreadchunksize = totalreadsize / numunreadchunks;
      numreadchunks = readchunksperdim(basepagedim) * prod(sizes(basepagedim+1:numdims));
      avgreadchunksize = totalreadsize / numreadchunks;
    end
    
    if dochunk
      % move selection of fastest dimensions to after fread
      for i=1:basepagedim-1
        if isempty(orderedselect{i})
          postselect{i} = [1:sizes(i)];
        else
          postselect{i} = orderedselect{i};
        end
      end
      [orderedselect{1:basepagedim-1}] = deal([]);
    end
    
    elemsinpage = prod(sizes(1:basepagedim-1));
    numpages = 0;
    if basepagedim > numdims
      numpages = 1;
    else
      numpages = prod(sizes(basepagedim:end));
    end
    
    % create progress bar
    % base progress on number of chunks and number of frags
    totalprogress = totalreadsize;
    p = [];
    curprogress = 0;
    lastprogress = curprogress;
    if ~noprogressbar
      p=progbar(sprintf('Reading %d%%...',round(100.0*curprogress/totalprogress)));
    end
    
    % Preallocate srs with correct dimensions
    srs = [];
    if length(newsizes) < 2
      newsizes = [ newsizes 1 ];
    end
    if ~isempty(info.elemtype) & ~strcmp(info.elemtype, 'float64') & ~strcmp(info.elemtype, 'double')
      matlabtype = typesizes(strcmp(info.elemtype,{typesizes.type})).matlabtype;
      singleton = feval(matlabtype,0);
      srs = repmat(singleton, newsizes);
    else
      srs = zeros(newsizes);
    end
    srspos = 1;
    
    % rangejumps is structured like orderedselect, but indicates the
    % index corresponding to the end of the contiguous range of
    % selected pages within that dimension
    rangejumps = {};
    for d = 1:numdims
      if isempty(orderedselect{d})
        rangejumps{d} = [];
      else
        startinds = find(diff([-1 orderedselect{d}]) > 1);
        endinds = find(diff([orderedselect{d} sizes(d)+2]) > 1);
        for i = 1:length(startinds)
          rangejumps{d}(startinds(i):endinds(i)) = endinds(i);
        end
      end
    end
    
    lastfilename = [];
    lastfid = -1;
    % coords is coordinates within orderedselect array
    % (empty orderedselect element is treated as full)
    coords = [];
    [coords(1:length(sizes))] = deal(1); % initialize to [1 1 ...]
    pagenum = local_coords2page(coords, sizes, orderedselect, numdims, basepagedim);
    while pagenum <= numpages
      % Precondition: "pagenum" is the number of the first
      %   unprocessed page containing valid data.  We are
      %   currently looking for the end of a range of valid
      %   data.  The last page in this range we have seen so far
      %   is "lastvalidpage".  Page numbers start at 1.
      %   "startfragnum" is for efficiency, so we don't parse
      %   frags we know we don't need anymore.
      
      firstvalidpage = pagenum;
      lastvalidpage = 0;
      
      % update coords/pagenum here for next page
      if basepagedim > numdims
        % shortcut
        firstvalidpage = 1;
        lastvalidpage = numpages;
        pagenum = numpages + 1;
      else
        baseselect = orderedselect{basepagedim};
        % jump to end of region in basepagedim
        if ~isempty(baseselect)
          coords(basepagedim) = rangejumps{basepagedim}(coords(basepagedim));
        end
        lastvalidpage = local_coords2page(coords, sizes, orderedselect, numdims, basepagedim);
        while 1
          nextcoords = local_coordsinc(coords, sizes, orderedselect, numdims, basepagedim);
          if isempty(nextcoords)
            break
          end
          nextpage = local_coords2page(nextcoords, sizes, orderedselect, numdims, basepagedim);
          coords = nextcoords;
          if nextpage ~= lastvalidpage + 1
            break
          end
          lastvalidpage = nextpage;
        end
        % calculate next page number
        if isempty(nextcoords)
          % made it all the way up, so must be end of data
          pagenum = numpages + 1;
        else
          pagenum = local_coords2page(coords, sizes, orderedselect, numdims, basepagedim);
        end
      end
      
      % Precondition:  We have a range of valid data, from
      %   "firstvalidpage" to "lastvalidpage".
      validbytesstart = ((firstvalidpage-1) * elemsinpage) * elemsize;
      validbytesstop = (lastvalidpage * elemsinpage) * elemsize;
      pages = [];
      pagepos = 1;
      numpagestoread = lastvalidpage + 1 - firstvalidpage;
      if ~isempty(postselect)
        pages = zeros([sizes(1:basepagedim-1) numpagestoread]);
      end

      startfragnum = index(find(fragends > validbytesstart), 1);
      fragsbeforeend = find(fragstarts < validbytesstop);
      endfragnum = fragsbeforeend(end);
      
      for fragnum=startfragnum:endfragnum
        fragpos = fragstarts(fragnum);
        frag = [];
        frag.filename = info.frags.filenames{fragnum};
        frag.fileoffset = info.frags.fileoffsets(fragnum);
        frag.fragsize = info.frags.fragsizes(fragnum);
        stopnow = 0;
        readfrag = [];
        if fragpos + frag.fragsize <= validbytesstart
          % this frag is before valid range, do nothing
        elseif fragpos >= validbytesstop
          % this frag is after valid range, so stop here
          stopnow = 1;
        elseif validbytesstart <= fragpos & ...
            fragpos + frag.fragsize <= validbytesstop
          % frag is completely valid, so read it unchanged
          readfrag = frag;
        else
          % valid range starts and/or ends in this frag so make
          % new frag to replace this one
          offsetdiff = 0; % will be added
          sizediff = 0;   % will be subtracted
          if fragpos <= validbytesstart
            % need to remove a bit from the front
            offsetdiff = offsetdiff + validbytesstart - fragpos;
            sizediff = sizediff + validbytesstart - fragpos;
          end
          if validbytesstop <= fragpos + frag.fragsize
            % need to truncate the end
            sizediff = sizediff + fragpos + frag.fragsize - validbytesstop;
            % we're at the end of the range so stop after reading
            stopnow = 1;
          end
          readfrag = frag;
          readfrag.fileoffset = readfrag.fileoffset + offsetdiff;
          readfrag.fragsize = readfrag.fragsize - sizediff;
        end
        if ~isempty(readfrag)
          readfilename = filename2url(readfrag.filename, info.basepath);
          readfilename = get(readfilename, 'Path');
          if strcmp(filesep, '\') & readfilename(1) == '/'
            readfilename = readfilename(2:end);
          end
          % On UNIX, fix pathnames that may have been generated on Windows
          if strcmp(filesep, '/')
            bsinds = find(readfilename == '\');
            readfilename(bsinds) = '/';
          end

          if ~noprogressbar  & curprogress == 0
            % update progress bar before the first frag (to display filename)
            endpos = length(readfilename) - 50;
            if endpos < 1, endpos = 1; end
            progbar(p,curprogress/totalprogress,sprintf('Read progress %d%%...\n(...%s)',round(100.0*curprogress/totalprogress),readfilename(endpos:end)));
                lastprogress = curprogress;
          end

          % read the frag
          fid = -1;
          if lastfid ~= -1 & strcmp(lastfilename,readfilename)
            fid = lastfid;
          else
            if lastfid ~= -1
              fclose(lastfid);
              lastfilename = '';
            end
            [fid,msg] = fopenlocation(readfilename, {'r', info.byteorder}, info.basepath);
            if fid==-1, emsg=msg; error(emsg); end
            lastfid = fid;
            lastfilename = readfilename;
          end
          if fseek(fid,readfrag.fileoffset,'bof')
            emsg=ferror(fid); fclose(fid); error(emsg);
          end
          elemsinfrag = readfrag.fragsize/elemsize;
          if isempty(postselect)
            [srs(srspos:srspos+elemsinfrag-1), count] = ...
              fread(fid, elemsinfrag, [info.rawelemtype '=>' info.elemtype]);
            if count ~= elemsinfrag
              fclose(fid);
              emsg = sprintf('Not enough data in file "%s"!', readfrag); error(emsg);
            end
            curprogress = curprogress + readfrag.fragsize;
            srspos = srspos + elemsinfrag;
          else
            [pages(pagepos:pagepos+elemsinfrag-1), count] = ...
              fread(fid, elemsinfrag, [info.rawelemtype '=>' info.elemtype]);
            if count ~= elemsinfrag
              fclose(fid);
              emsg = sprintf('Not enough data in file "%s"!', readfrag); error(emsg);
            end
            curprogress = curprogress + readfrag.fragsize;
            pagepos = pagepos + elemsinfrag;
          end
        end
        % finished a frag, so update progress
        if ~ishandle(p), fclose(fid); emsg='User abort'; error(emsg); end
        if ~noprogressbar
          % cut down updates to around 20 max
          if (curprogress - lastprogress) / totalprogress > .049
            readfilename = filename2url(readfrag.filename, info.basepath);
            readfilename = get(readfilename, 'Path');
            if strcmp(filesep, '\') & readfilename(1) == '/'
              readfilename = readfilename(2:end);
            end
            % On UNIX, fix pathnames that may have been generated on Windows
            if strcmp(filesep, '/')
              bsinds = find(readfilename == '\');
              readfilename(bsinds) = '/';
            end
            endpos = length(readfilename) - 50;
            if endpos < 1, endpos = 1; end
            progbar(p,curprogress/totalprogress,sprintf('Read progress %d%%...\n(...%s)',round(100.0*curprogress/totalprogress),readfilename(endpos:end)));
            lastprogress = curprogress;
          end
        end
        if stopnow
          break
        end
      end
      if ~isempty(postselect)
        % do final selection and copy data
        postselectedsize = [newsizes(1:basepagedim-1) numpagestoread];
        srs(srspos:srspos+prod(postselectedsize)-1) = ...
          pages(postselect{:}, [1:numpagestoread]);
        srspos = srspos + prod(postselectedsize);
      end
      firstvalidpage = 0;
      lastvalidpage = 0;
    end
    
    if lastfid ~= -1
      fclose(lastfid);
      lastfid = -1;
      lastfilename = '';
    end
  end
  
  % Check that we read enough data
  if srspos - 1 ~= prod(newsizes)
    emsg = 'Not enough data in files to fill output array!'; error(emsg);
  end
  
  %%% end Read data %%%
  %%%%%%%%%%%%%%%%%%%%%
  

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% Update info struct before returning data %%%
  
  % Focus only on selected data

  % fix up dimension origin, gap, spacing, datapoints if input select
  if isfield(info, 'inputselector')
    orderedselect = info.inputselector;
    for dimnum=1:length(info.dimensions)
      % (remember dimselect was modified to use indices starting at 1)
      dimselect = orderedselect{dimnum};
      if ~isempty(dimselect)
        dim = info.dimensions(dimnum);
        info.dimensions(dimnum) = local_do_dim_selection(info.dimensions(dimnum), dimselect);
      end
    end
  end
  
  % Permute/select dimensions if needed
  if isfield(info, 'permute') & ~isempty(info.permute)
    if ~noprogressbar
      progbar(p,'Permuting...');
    end
    srs = permute(srs, info.permute);
    if ~noprogressbar
      progbar(p,'Reshaping...');
    end
    srs = reshape(srs, info.inputnewsizes);
    info.dimensions = info.dimensions(info.permute);
    permkeepinds = setdiff([1:length(info.dimensions)], info.permdimdeleteinds);
    info.dimensions = [info.dimensions(permkeepinds)];
  end
  if isfield(info, 'outputselector') & ~isempty(info.outputselector)
    if ~noprogressbar
      progbar(p,'Selecting...');
    end
    srs = srs(info.outputselector{:});
    if ~noprogressbar
      progbar(p,'Reshaping...');
    end
  end
  if isfield(info.dimensions, 'outputselect')
    info.dimensions = rmfield(info.dimensions, 'outputselect');
  end
  
  % fix up dimension origin, gap, spacing, datapoints if output select
  if isfield(info, 'outputselector')
    orderedselect = info.outputselector;
    for dimnum=1:length(info.dimensions)
      % (remember dimselect was modified to use indices starting at 1)
      dimselect = orderedselect{dimnum};
      if ~isempty(dimselect)
        info.dimensions(dimnum) = local_do_dim_selection(info.dimensions(dimnum), dimselect);
      end
    end
  end

  %%% end Update info struct before returning data %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  

  %%%%%%%%%%%%%%%
  %%% Cleanup %%%
  
  % Get rid of internal (INFOONLY) fields
  
  if isfield(info, 'inputselector')
    info = rmfield(info, 'inputselector');
  end
  if isfield(info, 'outputselector')
    info = rmfield(info, 'outputselector');
  end
  if isfield(info, 'frags')
    info = rmfield(info, 'frags');
  end
  if isfield(info, 'basepath')
    info = rmfield(info, 'basepath');
  end
  if isfield(info, 'rawelemtype')
    info = rmfield(info, 'rawelemtype');
  end
  if isfield(info, 'permute')
    info = rmfield(info, 'permute');
  end
  if isfield(info, 'inputnewsizes')
    info = rmfield(info, 'inputnewsizes');
  end
  if isfield(info, 'outputnewsizes')
    info = rmfield(info, 'outputnewsizes');
  end
  if isfield(info, 'permdimdeleteinds')
    info = rmfield(info, 'permdimdeleteinds');
  end
  if isfield(info, 'rawdimensions')
    info = rmfield(info, 'rawdimensions');
  end
  
  % Delete progress bar (and set to [] for catch)
  delete(p); p=[];
  
  if ~inputisinfo | guiIsInfoStruct
    % Delete downloaded files
    local_deleteifintempdir(downloaded, inputlocs);
  end

  %%% end Cleanup %%%
  %%%%%%%%%%%%%%%%%%%
  
  varargout{1} = struct('data', srs, 'info', info);
  
catch
  if ishandle(p)
    delete(p); % Delete progress bar
  end
  
  if ~inputisinfo | guiIsInfoStruct
    % Delete downloaded files
    local_deleteifintempdir(downloaded, inputlocs);
  end
  
  if isempty(emsg)
    if isempty(lasterr)
      emsg='An unidentified error occurred!';
    else
      emsg=lasterr;
    end
  end
  error(emsg);
end

return

% --------------------------------------------------------------------
% --------------------------Local Functions---------------------------
% --------------------------------------------------------------------

function [files, downloaded] = local_downloadifneeded(locs)
% LOCAL_DOWNLOADIFNEEDED -- return local files and indicate which were downloaded

files = {};
downloaded = {};
if ~isempty(locs)
  for i=1:length(locs)
    locurl = locs{i};
    if ~isa(locs{i}, 'url')
      locurl = filename2url(locs{i});
    end
    proto = get(locurl,'Scheme');
    pathstr = get(locurl, 'Path');
    if strcmp('file', proto)
      downloaded{i} = [];
      files{i} = pathstr;
      if strcmp(filesep, '\') & files{i}(1) == '/'
        files{i} = files{i}(2:end);
      end
    else
      [downloaded{i}, emsg] = loadlocation(locurl);
      if ~isempty(emsg), error(emsg); end
      dots = findstr(pathstr, '.');
      if ~isempty(dots)
        % preserve extension
        newfilename = [downloaded{i} pathstr(dots(end):end)];
        [status, emsg] = copyfile(downloaded{i}, newfilename);
        if status == 0, error(emsg); end
        delete(downloaded{i});
        downloaded{i} = newfilename;
      end
      files{i} = downloaded{i};
    end
  end
end
return

function local_deleteifintempdir(files, locs)
% LOCAL_DELETEIFINTEMPDIR -- deletes files if they're in tempdir.
%
% If any input files are not in tempdir, a warning with msgid
% 'NOTTEMP' is thrown.  locs are the locations from which the
% files were downloaded.

for i=1:length(files)
  if ~isempty(files{i})
    if length(files{i}) >= length(tempdir) & findstr(files{i}, tempdir) == 1
      delete(files{i});
    else
      warning(sprintf('File "%s" (from location "%s") isn''t in tempdir, not deleting.', files{i}, locs{i}));
    end
  end
end
return

function fsizes = local_getfilesizes(files,trySpecFlag)
% LOCAL_GETFILESIZES -- get sizes of files, as returned by dir()
%
%   fsizes = getfilesizes(files)
%   fsizes = getfilesizes(files,trySpecFlag)
%
%   "files" can be a string or a cell array of strings.
%   Return value is a numeric array of file sizes in bytes.
%
%   trySpecFlag indicates whether or not to try to get the 
%     file sizes by generating a wildcard specifier (see name2spec).
%     This is only relevant if all files are in the same directory.
%   NOTE: Caching the file sizes from the original directory listing would 
%         be even faster than this mechanism!

if nargin < 2, trySpecFlag=1; end

% Put files in a cell array for uniform handling
if ischar(files), files = {files}; end

% Check if we can/should use the allinsamedir acceleration.
if length(files) == 1
  % Don't bother with this check for a single file. 
  % Just get the filesize using the simple method.
  allinsamedir = 0;
else
  % Check if all files are in the same directory
  fnames = cell(size(files));
  allinsamedir = 1;
  [commonpathstr,name,ext,vers] = fileparts(files{1});
  fnames{1} = [name ext vers];
  for i=2:length(files)
    [pathstr,name,ext,vers] = fileparts(files{i});
    fnames{i} = [name ext vers];
    if ~strcmp(commonpathstr, pathstr)
      allinsamedir = 0;
      clear('fnames');  % fnames is not complete, so make sure we don't use it accidentally.
      break
    end
  end
end
if allinsamedir
  % fast case
  dents=[];
  if trySpecFlag
    % Doing a directory listing using a wildcard is much faster
    % Try to make a wildcard match using first filename
    spec=name2spec(files{1});
    if ~strcmp(spec,files{1})  % Make sure that a spec was generated.
      dentsGuess = dir(spec);
      if length(dentsGuess)==length(files) & strcmp(sort({dentsGuess.name}),sort(fnames))
        % They match, use these dents
        dents=dentsGuess;
      end
      clear('dentsGuess','spec');
    end
  end
  if isempty(dents)
    % Didn't get a match.  List the entire directory
    dents = dir(commonpathstr);
  end
  try
    % MATLAB 6.5 ismember returns ind.
    [tf,ind]=ismember(fnames,{dents.name});
  catch
    % Previous versions do not.
    tf=ismember(fnames,{dents.name});
    ind=[];  % Calculate ind after we confirm that all fnames were found.
  end  
  if any(~tf), 
    missingFnames=fnames(find(~tf));
    str=repmat({sprintf('\n')},[length(missingFnames)*2-1,1]);
    str(1:2:end)=strcat([commonpathstr filesep],missingFnames);
    error(sprintf('Unable to read size of file(s):\n%s',[str{:}]))
  end
  if isempty(ind)
    % Find locations of each entry (for MATLAB 6.1 & older)
    % TODO: Find faster solution?
    ind=zeros(size(tf));
    for n=1:length(fnames)
      ind(n)=find(strcmp(fnames{n},{dents.name}));
    end
  end
  fsizes=[dents(ind).bytes];
else
  % slow case
  fsizes = zeros(size(files));
  for i=1:length(files)
    dent=dir(files{i});
    if isempty(dent), error(sprintf('Unable to read size of file: %s',files{i})); end
    fsizes(i)=dent.bytes;
  end
end
return

function pagenum=local_coords2page(coords, sizes, select, numdims, basepagedim)
% LOCAL_COORDS2PAGE -- return page number corresponding to coords
pagenum = 1;
gran = 1;
if basepagedim <= numdims
  gran = prod(sizes(basepagedim:numdims));
end
for i=numdims:-1:basepagedim
  gran = gran / sizes(i);
  if isempty(select{i})
    ind = coords(i);
  else
    ind = select{i}(coords(i));
  end
  pagenum = pagenum + (ind - 1) * gran;
end
return

function nextcoords=local_coordsinc(coords, sizes, select, numdims, basepagedim)
% LOCAL_COORDSINC -- return next coordinate
dimtoinc = basepagedim;
nextcoords = coords;
while dimtoinc <= numdims
  curcoord = nextcoords(dimtoinc);
  cursel = select{dimtoinc};
  cursize = sizes(dimtoinc);
  if (isempty(cursel) & curcoord == cursize) | ...
    (~isempty(cursel) & curcoord == length(cursel))
    nextcoords(dimtoinc) = 1;
    dimtoinc = dimtoinc + 1;
  else
    nextcoords(dimtoinc) = curcoord + 1;
    break
  end
end
if dimtoinc > numdims
  nextcoords = [];
end
return

function newdim=local_do_dim_selection(dim, dimselect)
% LOCAL_DO_DIM_SELECTION -- perform selection on dimension
if isfield(dim, 'datapoints') & ~isempty(dim.datapoints) & isnumeric(dim.datapoints{1}) & ~isnan(dim.datapoints{1})
  dim.datapoints = dim.datapoints(dimselect(:));
end
if isfield(dim, 'origin')
  if length(dimselect) <= 2 | all(diff(diff(dimselect)) == 0)
    % datapoints are evenly spaced
    dim.origin = dim.origin + (dim.spacing * (dimselect(1) - 1));
    if length(dimselect) >= 2
      dim.gap = dim.gap + dim.spacing * (dimselect(2) - dimselect(1) - 1);
      dim.spacing = dim.spacing * (dimselect(2) - dimselect(1));
    end
  else
    % datapoints are not evenly spaced
    if ~isfield(dim, 'datapoints') | isempty(dim.datapoints) | isnan(dim.datapoints{1})
      dim.datapoints = num2cell(dim.origin + ((dimselect - 1) * dim.spacing));
    end
    dim.origin = [NaN];
    dim.gap = [NaN];
    dim.spacing = [NaN];
  end
end
dim.size = length(dimselect);
newdim = dim;
return

function dim=local_create_dimdp(dimname, dimunits, datapoints)
% LOCAL_CREATE_DIMDP -- create a dimension struct given numeric array of datapoints (if more than one unique datapoint)
dim = [];
[uniqdps, uniqinds, recreateinds] = unique(datapoints);
uniqinds = sort(uniqinds); % make sure in original data order
uniqdps = datapoints(uniqinds); % make sure in original data order
if ~all(diff(diff(uniqinds)) == 0)
  emsg = sprintf('In attempting to create dimension "%s", unique datapoints have irregularly spaced indices:\n%s', dimname, num2str(uniqinds)); error(emsg);
end
if length(uniqdps) > 1
  % need to add as a new dimension
  dim.type = dimname;
  dim.units = dimunits;
  dim.size = length(uniqdps);
  dim.outputselect = NaN;
  if all(diff(diff(uniqdps)) == 0)
    % even spacing
    dim.origin = uniqdps(1);
    dim.spacing = uniqdps(2) - uniqdps(1);
    dim.gap = NaN;
    dim.datapoints = { NaN };
  else
    % irregular spacing
    dim.origin = NaN;
    dim.spacing = NaN;
    dim.gap = NaN;
    dim.datapoints = num2cell(datapoints(uniqinds));
  end
  dim.direction = [NaN NaN NaN];
  dim.directionprecision = NaN;
end
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [info,inputfiles,inputlocs,inputsizes]=local_dicom2mrinfo(inputfiles_in,inputlocs_in,inputsizes_in,dictionary,searchforothers)
% LOCAL_DICOM2MRINFO -- create an info struct given list of DICOM files.
%  This will deal appropriately with various 4-D DICOM formats, such as
%  produced by GE, Picker and Siemens (mosaic).
%  Based on code from bxh_dicom.cpp.

info = []; % allocate the header
inputfiles = inputfiles_in;
inputlocs = inputlocs_in;
inputsizes = inputsizes_in;

numoriginputs = length(inputfiles);

d = []; % this will have directory entries for the slices

if searchforothers
  [pathstr,name,ext,vers] = fileparts(inputfiles{1});
  d = dir(pathstr);
  inputfiles = strcat([pathstr filesep], {d.name});
  inputlocs = inputfiles;
  inputsizes = [d.bytes];
  % get rid of directories
  matchinds = [];
  for i=1:length(d)
    fullname = fullfile(pathstr, d(i).name);
    if exist(fullname, 'file') == 2
      matchinds(length(matchinds)+1) = i;
    end
  end
  d = d(matchinds);
  inputfiles = inputfiles(matchinds);
  inputlocs = inputlocs(matchinds);
  inputsizes = inputsizes(matchinds);
  % restrict to those files with the same extension
  % (unless extension is numeric)
  if ~isempty(ext) & isempty(str2num(ext))
    matchinds = [];
    for i=1:length(d)
      inds = [];
      if length(d(i).name) >= length(ext)
        inds = findstr(d(i).name, ext);
      end
      if ~isempty(inds) & (inds(end) == length(d(i).name) - length(ext) + 1)
        matchinds(length(matchinds)+1) = i;
      end
    end
    d = d(matchinds);
    inputfiles = inputfiles(matchinds);
    inputlocs = inputlocs(matchinds);
    inputsizes = inputsizes(matchinds);
  end
else
  clear d;
  for i=1:length(inputfiles)
    d(i) = dir(inputfiles{i});
  end
  inputsizes = [d.bytes];
end

slicenums = [];
matchinds = [];
blankfinfo = struct( ...
    'StudyInstanceUID', '', ...
    'SeriesInstanceUID', '', ...
    'ImageType', '', ...
    'Modality', '', ...
    'Manufacturer', '', ...
    'ImageOrientationPatient', [], ...
    'FlipAngle', [], ...
    'SliceThickness', [], ...
    'SpacingBetweenSlices', [], ...
    'ImagePositionPatient', [], ...
    'RepetitionTime', 0, ...
    'EchoTime', 0, ...
    'AcquisitionNumber', [], ...
    'Rows', [], ...
    'Columns', [], ...
    'BitsAllocated', [], ...
    'InstanceNumber', 0, ...
    'slicespacing', [], ...
    'slicethickness', [], ...
    't', 0, ...
    'parmrawdatatype2', 0, ...
    'gerawdatatype', [], ...
    'ismosaic', 0, ...
    'foundtimedim', 0);
baseinfo = [];
finfos = [];
for i=1:length(inputfiles)
  fullname = inputfiles{i};
  if ~isdicom(fullname), continue, end
  if ~isempty(dictionary)
    dinfo = dicominfo(fullname, 'dictionary', dictionary);
  else
    dinfo = dicominfo(fullname);
  end
  finfo = blankfinfo;
  reqfields = { 'StudyInstanceUID', 'SeriesInstanceUID', 'ImageType', 'Modality' };
  for reqfield=reqfields
    reqfield = reqfield{1};
    if ~isfield(dinfo, reqfield)
      emsg = ['DICOM file "' fullname '" is missing the field "' reqfield '"']; error(emsg);
    end
  end
  intfields = { 'StudyInstanceUID', 'SeriesInstanceUID', 'ImageType', 'Modality', 'Manufacturer', 'ImageOrientationPatient', 'FlipAngle', 'SliceThickness', 'SpacingBetweenSlices', 'ImagePositionPatient', 'RepetitionTime', 'EchoTime', 'AcquisitionNumber', 'Rows', 'Columns', 'BitsAllocated', 'InstanceNumber' };
  for fieldname=[reqfields intfields]
    fieldname = fieldname{1};
    if isfield(dinfo, fieldname)
      fieldval = getfield(dinfo, fieldname);
      % make sure numeric values are stored as doubles
      if isnumeric(fieldval)
        fieldval = double(fieldval);
      end
      finfo = setfield(finfo, fieldname, fieldval);
    end
  end
  imagetypes = splitstr(finfo.ImageType, '\\');
  finfo.ismosaic = ~isempty(strmatch('MOSAIC', imagetypes, 'exact'));
  finfo.slicethickness = double(finfo.SliceThickness);
  if ~isempty(finfo.SpacingBetweenSlices)
    finfo.slicespacing = double(finfo.SpacingBetweenSlices);
  else
    finfo.slicespacing = double(finfo.slicethickness);
  end
  if strcmp(finfo.Manufacturer, 'GE MEDICAL SYSTEMS')
    if isfield(dinfo, 'Private_0043_10xx_Creator') & ...
          strcmp(dinfo.Private_0043_10xx_Creator, 'GEMS_PARM_01') & ...
          isfield(dinfo, 'Private_0043_102f')
      finfo.gerawdatatype = double(dinfo.Private_0043_102f);
    end
  end
  if finfo.ismosaic & ...
        (isfield(dinfo, 'ImageDate') | isfield(dinfo, 'ContentDate')) & ...
        (isfield(dinfo, 'ImageTime') | isfield(dinfo, 'ContentTime'))
    if isfield(dinfo, 'ImageDate')
      id = dinfo.ImageDate;
    else
      id = dinfo.ContentDate;
    end
    if isfield(dinfo, 'ImageTime')
      it = dinfo.ImageTime;
    else
      it = dinfo.ContentTime;
    end
    dvec = [...
        str2num(id(1:4)) ...
        str2num(id(5:6)) ...
        str2num(id(7:8)) ...
        str2num(it(1:2)) ...
        str2num(it(3:4)) ...
        str2num(it(5:end))];
    finfo.t = etime(dvec, [1970 1 1 0 0 0]);
    finfo.foundtimedim = 1;
  elseif isfield(dinfo, 'TemporalPositionIdentifier')
    % TemporalPositionIdentifier is indexed by 1, so shift to 0
    finfo.t = double(dinfo.TemporalPositionIdentifier) - 1;
    if isfield(dinfo, 'TemporalResolution')
      finfo.t = finfo.t * double(dinfo.TemporalResolution);
    end
    finfo.foundtimedim = 1;
  end
  % this is BIAC-specific
  if isfield(dinfo, 'Private_0019_10xx_Creator') & ...
        strcmp(dinfo.Private_0019_10xx_Creator, 'GEMS_ACQU_01') & ...
        isfield(dinfo, 'Private_0019_109c') & ...
        strcmp(dinfo.Private_0019_109c, 'epi2NV') & ... % GEMS_PulseSequenceName
        isfield(dinfo, 'Private_0043_10xx_Creator') & ...
        strcmp(dinfo.Private_0043_10xx_Creator, 'GEMS_PARM_01') & ...
        isfield(dinfo, 'Private_0043_1030') % GEMS_ParmRawDataType2
    finfo.parmrawdatatype2 = double(dinfo.Private_0043_1030);
  end
  
  matched = 1;
  if ~isempty(baseinfo)
    if ~strcmp(finfo.StudyInstanceUID, baseinfo.StudyInstanceUID) | ...
          ~strcmp(finfo.SeriesInstanceUID, baseinfo.SeriesInstanceUID) | ...
          ~strcmp(finfo.ImageType, baseinfo.ImageType) | ...
          ~strcmp(finfo.Modality, baseinfo.Modality) | ...
          (finfo.ismosaic ~= baseinfo.ismosaic) | ...
          (finfo.foundtimedim ~= baseinfo.foundtimedim) | ...
          (~finfo.ismosaic & strcmp(finfo.Modality, 'CT') & finfo.AcquisitionNumber ~= baseinfo.AcquisitionNumber) | ...
          any(abs(finfo.ImageOrientationPatient - baseinfo.ImageOrientationPatient) > 0.000002) | ...
          (finfo.FlipAngle ~= baseinfo.FlipAngle) | ...
          (strcmp(finfo.Manufacturer, 'GE MEDICAL SYSTEMS') & finfo.gerawdatatype ~= baseinfo.gerawdatatype)
      matched = 0;
    end
  end
  if matched
    matchinds(length(matchinds)+1) = i;
    if isempty(finfos)
      baseinfo = finfo;
    end
    if isempty(finfos)
      finfos = finfo;
    else
      finfos(end+1) = finfo;
    end
  elseif numoriginputs > 1
    emsg = 'Specified DICOM files do not match in some fields'; error(emsg);
  end
end

% sort finfos according to all relevant dimensions
sortindexes = [1:length(finfos)];
[sorted, si] = sort([finfos.InstanceNumber]);
finfos = finfos(si);
sortindexes = sortindexes(si);
[sorted, si] = sort([finfos.t]);
finfos = finfos(si);
sortindexes = sortindexes(si);
[sorted, si] = sort([finfos.RepetitionTime]);
finfos = finfos(si);
sortindexes = sortindexes(si);
[sorted, si] = sort([finfos.EchoTime]);
finfos = finfos(si);
sortindexes = sortindexes(si);
[sorted, si] = sort([finfos.parmrawdatatype2]);
finfos = finfos(si);
sortindexes = sortindexes(si);
keepthese = matchinds(sortindexes);
d = d(keepthese);
inputfiles = inputfiles(keepthese);
inputlocs = inputlocs(keepthese);
inputsizes = inputsizes(keepthese);

% keep only the first of each run of repeated origins
% (unless all files have the same origin)
origins = reshape([finfos.ImagePositionPatient], [3 length(finfos)]);
dists = origins - [(origins(:,1)-1) origins(:,1:end-1)];
dists = sqrt(sum(dists .^ 2));
uniq = find(dists >= (0.001 * finfos(1).slicespacing));
if length(uniq) > 1
  if numoriginputs > 1 & length(uniq) ~= length(finfos)
    emsg = sprintf('You have specified multiple DICOM files, but I can''t make sense of their origins.\nTry specifying just one file (no wildcards) and using ''DICOM'' or ''DICOM_Search'' as the input type.'); error(emsg);
  end
  finfos = finfos(uniq);
  d = d(uniq);
  inputfiles = inputfiles(uniq);
  inputlocs = inputlocs(uniq);
  inputsizes = inputsizes(uniq);
end
% run through origins in each file to see if they wrap around;
% if so, assume it is a time series and adjust accordingly.
if ~baseinfo.foundtimedim
  origins = reshape([finfos.ImagePositionPatient], [3 length(finfos)]);
  dists = origins - repmat(origins(:,1), [1 length(finfos)]);
  dists = sqrt(sum(dists .^ 2));
  matches = find(dists < (0.001 * finfos(1).slicespacing));
  if length(matches) >= 2 % first slice doesn't count
    numslices = matches(2) - 1;
    disp(sprintf('Note: detected wrap-around in slice origins -- assuming %d slices per timepoint.', numslices));
    trs = [finfos(1:numslices:end).RepetitionTime];
    if any(trs == 0)
      disp('Note: some slices don''t have TR specified -- assuming 1000ms.');
      trs(trs == 0) = 1000;
    end
    timepoints = repmat([0 cumsum(trs(1:end-1))], [numslices 1]);
    ct = num2cell([timepoints(:)]);
    [finfos.t] = deal(ct{:});
  end
end

finfo = finfos(1);
if ~isempty(dictionary)
  dinfo = dicominfo(inputfiles{1}, 'dictionary', dictionary);
else
  dinfo = dicominfo(inputfiles{1});
end

siemensmap = struct('pfov', [], 'rfov', [], 'lsize', 0, ...
                    'posSag0', 0, 'posCor0', 0, 'posTra0', 0, ...
                    'posSagN', 0, 'posCorN', 0, 'posTraN', 0, ...
                    'norSag0', 0, 'norCor0', 0, 'norTra0', 0);

if strcmp(dinfo.Manufacturer, 'SIEMENS') & ...
      isfield(dinfo, 'Private_0029_10xx_Creator') & ...
      strcmp(dinfo.Private_0029_10xx_Creator, 'SIEMENS CSA HEADER') & ...
      isfield(dinfo, 'Private_0029_1020')
  begstr = sprintf('### ASCCONV BEGIN ###\n');
  endstr = sprintf('### ASCCONV END ###\n');
  ascconv = char(dinfo.Private_0029_1020)';
  if length(ascconv) >= (length(begstr) + length(endstr))
    ascconv((ascconv < 32 & ascconv ~= 10) | (ascconv > 126)) = ' ';
    begpos = findstr(ascconv, begstr);
    endpos = findstr(ascconv, endstr);
    if ~isempty(begpos) & ~isempty(endpos)
      ascconv = ascconv(begpos+length(begstr):endpos-1);
      ascconv(ascconv == '=') = sprintf('\n');
      ascconv = splitstr(ascconv, '\n');
      names = ascconv(1:2:end-1);
      values = ascconv(2:2:end);
      inds = strmatch('sSliceArray.asSlice[0].dPhaseFOV', names);
      if ~isempty(inds)
        siemensmap.pfov = str2num(values{inds(1)});
      end
      inds = strmatch('sSliceArray.asSlice[0].dReadoutFOV', names);
      if ~isempty(inds)
        siemensmap.rfov = str2num(values{inds(1)});
      end
      inds = strmatch('sSliceArray.lSize', names);
      if ~isempty(inds)
        siemensmap.lsize = str2num(values{inds(1)});
      end
      inds = strmatch('sSliceArray.asSlice[0].sPosition.dSag', names);
      if ~isempty(inds)
        siemensmap.posSag0 = str2num(values{inds(1)});
      end
      inds = strmatch('sSliceArray.asSlice[0].sPosition.dCor', names);
      if ~isempty(inds)
        siemensmap.posCor0 = str2num(values{inds(1)});
      end
      inds = strmatch('sSliceArray.asSlice[0].sPosition.dTra', names);
      if ~isempty(inds)
        siemensmap.posTra0 = str2num(values{inds(1)});
      end
      lsstr = num2str(siemensmap.lsize - 1);
      inds = strmatch(['sSliceArray.asSlice[' lsstr '].sPosition.dSag'], names);
      if ~isempty(inds)
        siemensmap.posSagN = str2num(values{inds(1)});
      end
      inds = strmatch(['sSliceArray.asSlice[' lsstr '].sPosition.dCor'], names);
      if ~isempty(inds)
        siemensmap.posCorN = str2num(values{inds(1)});
      end
      inds = strmatch(['sSliceArray.asSlice[' lsstr '].sPosition.dTra'], names);
      if ~isempty(inds)
        siemensmap.posTraN = str2num(values{inds(1)});
      end
      inds = strmatch('sSliceArray.asSlice[0].sNormal.dSag', names);
      if ~isempty(inds)
        siemensmap.norSag0 = str2num(values{inds(1)});
      end
      inds = strmatch('sSliceArray.asSlice[0].sNormal.dCor', names);
      if ~isempty(inds)
        siemensmap.norCor0 = str2num(values{inds(1)});
      end
      inds = strmatch('sSliceArray.asSlice[0].sNormal.dTra', names);
      if ~isempty(inds)
        siemensmap.norTra0 = str2num(values{inds(1)});
      end
    end
  end
end

% need to grab acqcols and acqrows for mosaic
acqcols = [];
acqrows = [];
if ~isempty(siemensmap.pfov) & ~isempty(siemensmap.rfov)
  if isfield(dinfo, 'PhaseEncodingDirection')
    ped = dinfo.PhaseEncodingDirection;
  elseif isfield(dinfo, 'InPlanePhaseEncodingDirection')
    ped = dinfo.InPlanePhaseEncodingDirection;
  else
    emsg = 'Error finding PhaseEncodingDirection in DICOM file'; error(emsg);
  end
  if strcmp(ped, 'ROW')
    colfov = siemensmap.rfov;
    rowfov = siemensmap.pfov;
  elseif strcmp(ped, 'COL')
    colfov = siemensmap.pfov;
    rowfov = siemensmap.rfov;
  else
    emsg = sprintf('Error parsing PhaseEncodingDirection ("%s")', ped); error(emsg);
  end
  acqcols = colfov / dinfo.PixelSpacing(1);
  acqrows = rowfov / dinfo.PixelSpacing(2);
elseif isfield(dinfo, 'AcquisitionMatrix')
  acqmatrix = dinfo.AcquisitionMatrix;
  if acqmatrix(1) == acqmatrix(2) | acqmatrix(3) == acqmatrix(4)
    emsg = 'Can''t interpret DICOM Acquisition Matrix'; error(emsg);
  end
  acqrows = acqmatrix(1); % freqrows
  acqcols = acqmatrix(2); % freqcols
  if acqmatrix(3) ~= 0, acqrows = acqmatrix(3); end % phaserows
  if acqmatrix(4) ~= 0, acqcols = acqmatrix(4); end % phasecols
end

% first assign dimx/dimy/etc.
if finfo.ismosaic
  info.dimensions = struct( ...
      'type', {'x','z-split1','y','z-split2'}, ...
      'units', NaN, ...
      'size', {acqcols, dinfo.Columns/acqcols, acqrows, length(inputfiles) * (dinfo.Rows/acqrows)}, ...
      'outputselect', {NaN,NaN,NaN,[1:siemensmap.lsize]}, ...
      'origin', NaN, ... % rest will be filled in later
      'spacing', NaN, ...
      'gap', NaN, ...
      'datapoints', {{NaN}}, ...
      'direction', NaN, ...
      'directionprecision', NaN);
  extradimstart = 5;
else
  info.dimensions = struct( ...
      'type', {'x','y','z'}, ...
      'units', NaN, ...
      'size', {dinfo.Columns, dinfo.Rows, length(inputfiles)}, ...
      'outputselect', NaN, ...
      'origin', NaN, ... % rest will be filled in later
      'spacing', NaN, ...
      'gap', NaN, ...
      'datapoints', {{NaN}}, ...
      'direction', NaN, ...
      'directionprecision', NaN);
  extradimstart = 4;
end

% find new dimensions if they exist
dimt = local_create_dimdp('t', 'ms', [finfos.t]);
dimtr = local_create_dimdp('tr', 'ms', [finfos.RepetitionTime]);
dimte = local_create_dimdp('te', 'ms', [finfos.EchoTime]);
dimbmatrix = local_create_dimdp('bmatrix', '', [finfos.parmrawdatatype2]);
info.dimensions = [ info.dimensions dimt dimtr dimte dimbmatrix ];

dimxind = strmatch('x', {info.dimensions.type}, 'exact');
dimyind = strmatch('y', {info.dimensions.type}, 'exact');
dimzind = strmatch('z', {info.dimensions.type}, 'exact');
dimtind = strmatch('t', {info.dimensions.type}, 'exact');
dimteind = strmatch('te', {info.dimensions.type}, 'exact');
dimtrind = strmatch('tr', {info.dimensions.type}, 'exact');
dimbmatrixind = strmatch('bmatrix', {info.dimensions.type}, 'exact');
if finfo.ismosaic
  dimzind = strmatch('z-split2', {info.dimensions.type}, 'exact');
end

% fix z size to account for new dimensions (e.g. 't' [time])
extradimsizes = [info.dimensions(extradimstart:end).size];
newzsize = info.dimensions(dimzind).size / prod(extradimsizes);
if newzsize ~= fix(newzsize)
  emsg = sprintf('Extra dimensions'' (%s) sizes (%s) don''t divide number of slices (%d) equally!', num2str([extradimstart:length(info.dimensions)]), num2str(extradimsizes), info.dimensions(dimzind).size); error(emsg);
end
info.dimensions(dimzind).size = newzsize;

% calculate slice spacing here because we now know true number of slices
calcslicespacing = 0;
origin0 = [];
originN = [];
if finfo.ismosaic
  numslices = siemensmap.lsize;
  origin0 = [ ...
      siemensmap.posSag0 * -1,  % lps->ras
      siemensmap.posCor0 * -1,  % lps->ras
      siemensmap.posTra0 ];
  originN = [ ...
      siemensmap.posSagN * -1,  % lps->ras
      siemensmap.posCorN * -1,  % lps->ras
      siemensmap.posTraN ];
elseif length(inputfiles) > 1
  numslices = info.dimensions(dimzind).size;
  origin0 = finfos(1).ImagePositionPatient' .* [-1 -1 1]; % lps->ras
  originN = finfos(end).ImagePositionPatient' .* [-1 -1 1]; % lps->ras
end
if ~isempty(origin0)
  calcslicespacing = sqrt(sum((origin0 - originN) .^ 2)) / (numslices - 1);
  epsilon = 0.005;
  if abs(calcslicespacing - finfo.slicespacing) > epsilon
    disp(sprintf('Note: reported slice spacing (%g) is different from calculated\n spacing (%g) by more than %g.  Using calculated number.', finfo.slicespacing, calcslicespacing, epsilon));
  end
end
if finfo.slicespacing == finfo.slicethickness
  finfo.slicethickness = calcslicespacing;
end

info.dimensions(dimxind).spacing = dinfo.PixelSpacing(1);
info.dimensions(dimyind).spacing = dinfo.PixelSpacing(2);
info.dimensions(dimzind).spacing = calcslicespacing;
info.dimensions(dimxind).gap = 0;
info.dimensions(dimyind).gap = 0;
info.dimensions(dimzind).gap = calcslicespacing - finfo.slicethickness;
[info.dimensions([dimxind dimyind dimzind]).units] = deal('mm');

% set origin and direction
directions = reshape(dinfo.ImageOrientationPatient' .* [-1 -1 1 -1 -1 1], [3 2])';
normal = cross(directions(1,:), directions(2,:));
if finfo.ismosaic | length(inputfiles) > 1
  % get normal in the correct data direction
  if finfo.ismosaic
    newnormal = [siemensmap.norSag0 siemensmap.norCor0 siemensmap.norTra0] .* [-1 -1 1];
  else
    newnormal = (finfos(end).ImagePositionPatient' .* [-1 -1 1]) - (finfos(1).ImagePositionPatient' .* [-1 -1 1]);
  end
  % normalize vector
  newnormal = newnormal / sqrt(sum(newnormal .^ 2));
  epsilon = 0.05;
  if ~(all(newnormal - normal < epsilon) | all(newnormal + normal < epsilon))
    disp(sprintf('Warning: slice origins don''t lie along a vector parallel to normal'));
    disp(sprintf(' Cross-product of rows & columns: (%.15g, %.15g, %.15g)', normal(1), normal(2), normal(3)));
    disp(sprintf(' Origins vector: (%.15g, %.15g, %.15g)', newnormal(1), newnormal(2), newnormal(3)));
    disp(sprintf(' Continuing anyway...'));
  end
  directions(3,:) = newnormal;
else
  directions(3,:) = normal;
end
[max1, maxind1] = max(abs(directions(1,:)));
[max2, maxind2] = max(abs(directions(2,:)));
[max3, maxind3] = max(abs(directions(3,:)));
order = [maxind1 maxind2 maxind3];
dimrind = find(order == 1);
dimaind = find(order == 2);
dimsind = find(order == 3);
if finfo.ismosaic
  % mosaic DICOM origin is incorrect; use values in ASCII header
  % these are center of slice, so move to center of top-left voxel
  info.dimensions(dimrind).origin = (-1 * siemensmap.posSag0) + (-0.5 * (directions(1,1) * dinfo.PixelSpacing(1) * (acqcols - 1)) + (directions(2,1) * dinfo.PixelSpacing(2) * (acqrows -1)));
  center = [siemensmap.posSag0 siemensmap.posCor0 siemensmap.posTra0] .* [-1 -1 1];
  corner = center + (-0.5 * (directions(1,:) * dinfo.PixelSpacing(1) * (acqcols - 1) + (directions(2,:) * dinfo.PixelSpacing(2) * (acqrows - 1))));
  info.dimensions(dimrind).origin = corner(1);
  info.dimensions(dimaind).origin = corner(2);
  info.dimensions(dimsind).origin = corner(3);
else
  info.dimensions(dimrind).origin = dinfo.ImagePositionPatient(1) * -1; % lps->ras
  info.dimensions(dimaind).origin = dinfo.ImagePositionPatient(2) * -1; % lps->ras
  info.dimensions(dimsind).origin = dinfo.ImagePositionPatient(3);
end
info.dimensions(dimxind).direction = directions(1,:);
info.dimensions(dimyind).direction = directions(2,:);
info.dimensions(dimzind).direction = directions(3,:);

if strcmp(dinfo.Manufacturer, 'GE MEDICAL SYSTEMS')
  % fix origin to point to center of voxels
  % (x and y dimensions use edge of bounding box in GE)
  origin = [info.dimensions([dimrind dimaind dimsind]).origin];
  origin = ...
      origin + ...
      (info.dimensions(dimxind).spacing / 2.0) * directions(1,:) + ...
      (info.dimensions(dimyind).spacing / 2.0) * directions(2,:);
  info.dimensions(dimrind).origin = origin(1);
  info.dimensions(dimaind).origin = origin(2);
  info.dimensions(dimsind).origin = origin(3);
end

if mod(dinfo.BitsAllocated, 8) ~= 0
  emsg=sprintf('Pixel bits allocated is not a multiple of 8! (%d)', dinfo.BitsAllocated); error(emsg);
end
if dinfo.PixelRepresentation == 1
  info.rawelemtype = ['int' num2str(dinfo.BitsAllocated)];
elseif dinfo.PixelRepresentation == 0
  info.rawelemtype = ['uint' num2str(dinfo.BitsAllocated)];
end
info.elemtype = '';
info.outputelemtype = info.rawelemtype;

if strcmp(dinfo.FileStruct.Current_Endian, 'ieee-le')
  info.byteorder = 'l';
elseif strcmp(dinfo.FileStruct.Current_Endian, 'ieee-be')
  info.byteorder = 'b';
else
  emsg=sprintf('Don''t know byte order "%s"', dinfo.FileStruct.Current_Endian); error(emsg);
end

info.hdr = dinfo;
info.hdrtype = 'DICOM';

% do frags
nbytes = double(dinfo.Rows) * double(dinfo.Columns) * double(dinfo.BitsAllocated) / 8;
info.frags = [];
info.frags.filenames = inputfiles;
info.frags.fileoffsets = inputsizes - nbytes;
info.frags.fragsizes = repmat(nbytes, [1 length(inputfiles)]);
info.basepath = '';

return

% Modification History:
%
% $Log: readmr.m,v $
% Revision 1.73  2005/06/17 15:22:05  gadde
% Move from array of frag structures to frag list structure of arrays.
%
% Revision 1.72  2005/06/14 14:57:54  gadde
% More DICOM numeric field conversions to double...
%
% Revision 1.71  2005/06/14 13:19:41  gadde
% Make sure all numeric DICOM fields are interpreted and stored as doubles
% (inspired by update 1.49.2.5)
%
% Revision 1.70  2005/06/08 18:26:03  gadde
% fix bad variable names
%
% Revision 1.69  2005/06/08 18:17:15  gadde
% Remove heading slash '/' from URL paths if on Windows.
%
% Revision 1.68  2005/06/08 16:01:54  gadde
% Perform filename slash conversion before reading frags.
%
% Revision 1.67  2005/05/12 18:40:13  gadde
% Don't allow wildcards with 4-D Analyze files.
%
% Revision 1.66  2005/03/16 15:09:05  gadde
% Fix unreadchunksperdim calculation -- should be 1 for a dimension of
% size n if the selector is [1:(n-1)].
%
% Revision 1.65  2005/02/03 17:16:52  michelich
% M-lint: Add missing commas.
%
% Revision 1.64  2005/02/03 16:58:41  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.63  2004/09/23 14:59:01  gadde
% Standardize dimension field list and order.
%
% Revision 1.62  2004/09/23 14:33:34  gadde
% Remove dimensions.outputselect field even if empty.
%
% Revision 1.61  2004/09/23 14:12:00  gadde
% Remove dimensions.outputselect field even if no permutation is needed.
%
% Revision 1.60  2004/08/09 15:54:50  gadde
% Update 'DICOM' behavior to not search other files.
%
% Revision 1.59  2004/08/09 13:53:34  gadde
% Get rid of reference to 'readmr help'.
%
% Revision 1.58  2004/08/09 13:48:33  gadde
% Remove references to cleanupmrinfo.
% Prefix all local functions with "local_".
% More complete DICOM reading intelligence (and moved to helper function).
%
% Revision 1.57  2004/06/17 17:54:34  gadde
% clean up dimension selection
%
% Revision 1.56  2004/05/28 20:22:43  gadde
% Calculate output sizes / outputselectors correctly for permuted
% data.
%
% Revision 1.55  2004/05/06 15:15:34  gadde
% Remove all dependencies on ispc and nargoutchk (for compatibility
% with Matlab 5.3).
%
% Revision 1.54  2004/05/06 14:47:39  gadde
% Replace all uses of strfind with findstr (strfind doesn't exist before
% Matlab 6.1).
%
% Revision 1.53  2004/04/14 16:13:10  gadde
% Code clarification.
%
% Revision 1.52  2004/03/23 16:24:53  michelich
% Added infoonly mode GUI example to help.
%
% Revision 1.51  2004/03/15 20:31:47  gadde
% Add some missing logic and revert a previous illogic.
%
% Revision 1.50  2004/03/15 16:09:16  gadde
% Minor logic fix.
%
% Revision 1.49  2004/02/03 19:20:28  michelich
% Fixed native returnelemtype.
% Use feval instead of eval to generate singleton (safer).
%
% Revision 1.48  2004/01/23 22:02:35  gadde
% Make sure INFOONLY struct has correct dimension size with outputselect.
%
% Revision 1.47  2004/01/23 19:24:29  gadde
% Cleanup and variable renaming.
%
% Revision 1.46  2004/01/22 16:41:12  gadde
% Encourage 'float64' instead of 'double', but support those type
% names that aren't Matlab types.
%
% Revision 1.45  2003/12/03 16:21:10  gadde
% Add one more progress bar update (before reading first frag).
%
% Revision 1.44  2003/10/24 17:36:46  gadde
% Convert lps DICOM coordinates to ras.
%
% Revision 1.43  2003/10/22 18:36:41  gadde
% Don't remove necessary fields from dimensions.
%
% Revision 1.42  2003/10/22 18:11:09  gadde
% Fix outputselector again.
%
% Revision 1.41  2003/10/22 18:03:15  gadde
% Fix outputselector handling.
%
% Revision 1.40  2003/10/22 17:43:28  gadde
% Populate outputselector even if outputselect doesn't exist.
%
% Revision 1.39  2003/10/22 15:54:38  gadde
% Make some CVS info accessible through variables
%
% Revision 1.38  2003/10/22 15:32:58  gadde
% Make CVS Id acessible through a variable;
%
% Revision 1.37  2003/10/22 15:31:36  gadde
% Add support for outputselect attribute
%
% Revision 1.35  2003/10/21 17:14:37  gadde
% Fix logic in DICOM check.
%
% Revision 1.34  2003/10/14 14:58:53  gadde
% Name change: geturlfromfile => filename2url
%
% Revision 1.33  2003/10/13 20:45:24  gadde
% Update to return correct number of arguments for old-style convention.
%
% Revision 1.32  2003/09/25 20:54:55  gadde
% Make sure datapoints is a cell array
%
% Revision 1.31  2003/09/10 16:08:45  michelich
% Give better error message if file missing in getfilesizes slow case.
%
% Revision 1.30  2003/08/25 17:00:11  gadde
% Add "displayname" field.
%
% Revision 1.29  2003/08/15 15:32:30  michelich
% Use cell2struct to create formats.
% Sort files when expanding wildcards (since dir does not guarantee order).
%
% Revision 1.28  2003/07/28 22:50:44  michelich
% Updates to getfilesizes() local function:
%   Fixed variable name in slow case.
%   Don't use fast case for single files since wildcard listing takes longer.
%
% Revision 1.27  2003/07/23 17:03:10  gadde
% Warn if dimorder doesn't have same length as dimsizes in 'Raw' typespec.
%
% Revision 1.26  2003/07/23 15:42:44  gadde
% Allow opt_dimorder argument and Inf for opt_recsize.
%
% Revision 1.25  2003/07/16 14:54:07  gadde
% If we change data filenames for Analyze (.hdr -> .img), update filesizes
% too.  And do this for all input files.
%
% Revision 1.24  2003/07/03 20:22:31  gadde
% Use more consistent elemtype description in info by adding
% rawelemtype (input) and outputelemtype (output).
%
% Revision 1.23  2003/07/03 14:14:27  gadde
% Fix check for selector in INFOONLY mode.
%
% Revision 1.22  2003/07/03 01:47:23  michelich
% Handle mrinfo returned from readmrgui properly.
% Remove array element more efficiently.
%
% Revision 1.21  2003/07/02 22:23:07  michelich
% Removed warning msgid for MATLAB 6.1 compatibility.
%
% Revision 1.20  2003/07/02 20:37:33  gadde
% Fix some UNC path bugs
%
% Revision 1.19  2003/07/02 19:58:47  gadde
% Add missing geturlfromfile call
%
% Revision 1.18  2003/07/02 19:05:22  gadde
% Fix bug which results from changing directories between getting
% an INFOONLY struct and actually reading the data.
%
% Revision 1.17  2003/07/02 16:03:58  gadde
% Pretty-up documentation and fix an error message.
%
% Revision 1.16  2003/07/02 15:01:45  gadde
% Avoid a call to getfilesizes if recSz is provided.
% Update documentation.
%
% Revision 1.15  2003/07/01 20:33:46  gadde
% Make sure endinds is not empty!
%
% Revision 1.14  2003/07/01 20:21:35  michelich
% Specify recSz for Legacy formats in "old-style" support.
%
% Revision 1.13  2003/07/01 18:30:37  gadde
% Move hdrSz to end of Raw parameters and add opt_recSz to allow for footers.
%
% Revision 1.12  2003/06/30 22:21:09  michelich
% Removed unimplemented ScreenSave and Legacy formats from valid READMR formats.
% Remove unused fields from formats structure.
% Changed "old-style" parameter handling
% - Don't allow wildcards.
% - Implement handing of ScreenSave, CORITechs, ANMR, EP, Signa4.
% - Added better error message for DICOM_AVW_VolumeFile.
% - Return last filename for multi-file formats.
%
% Revision 1.11  2003/06/30 20:28:27  gadde
% Fix rangejumps
%
% Revision 1.10  2003/06/30 17:53:08  michelich
% Added description of supported "old-style" formats.
% Fixed "Raw" read parameters in "old-style" support.
%
% Revision 1.9  2003/06/30 17:40:50  gadde
% Fix backwards-compatible 'allInOne' behavior (for Signa5).
% Move validation of dimension sizes in old-style code to apply to all
% canned formats.
%
% Revision 1.8  2003/06/30 17:12:54  michelich
% Allow three output arguments when using "old-style" arguments.
%
% Revision 1.7  2003/06/30 16:54:30  michelich
% Updated for readmr name change.
%
% Revision 1.6  2003/06/30 13:55:51  michelich
% Renamed readmrtest.m to readmr.m
%
% --- All revisions listed below are in readmrtest.m,v ---
% Revision 1.106  2003/06/30 06:20:35  michelich
% Updated for readmrgui name change.
%
% Revision 1.105  2003/06/30 01:55:26  michelich
% Cache file sizes instead of full directory entries.
% Don't get file sizes for single files until they are needed.  This also
%   allows using faster getfilesizes() when a wildcard expanded cell array of
%   filenames is specified as inputlocs.
% Use trySpecFlag = 1 by default for getfilesizes().
% Bug Fix: Handle getting file sizes of mixtures of URLs and files properly.
%
% Revision 1.104  2003/06/29 20:55:23  michelich
% Bug Fix: Use NaN not [] for default voxSz and orient for Analyze7.5_SPM.
% Use -1 to indicate GUI instead of [] (less likely to call by accident).
% Simplified creation of info.dimensions from mrparams.
% Return empty ans on cancel.
%
% Revision 1.103  2003/06/27 20:45:02  gadde
% Performance enhancement -- don't increment in basepagedim,
% just jump to end of range.
%
% Revision 1.102  2003/06/25 21:10:06  gadde
% Add precision to direction vectors
%
% Revision 1.101  2003/06/18 18:36:56  gadde
% Use empty character string for units.
%
% Revision 1.100  2003/06/18 18:25:24  gadde
% Make empty units if we don't know them.
%
% Revision 1.99  2003/06/17 19:34:36  gadde
% Remove basepath field.
%
% Revision 1.98  2003/06/17 17:04:33  gadde
% Performance enhancement (don't construct chunks greater than 1MB).
%
% Revision 1.97  2003/06/17 15:35:29  gadde
% Allow simple (i.e. regularly spaced) selectors for split dimensions.
%
% Revision 1.96  2003/06/16 17:31:23  gadde
% Change 'url' variable name to not conflict with class name
%
% Revision 1.95  2003/06/16 17:28:27  gadde
% Change URL to lowercase (to avoid problems on Win32 Matlab).
%
% Revision 1.94  2003/06/13 17:16:26  gadde
% Check for NaN in datapoints field.
%
% Revision 1.93  2003/06/13 15:58:43  gadde
% Keep the last (instead of first) of merged split dimensions.
% dicom2bxh puts all relevant info (direction, etc.) in last split.
%
% Revision 1.92  2003/06/06 15:54:15  michelich
% Fixed adding =>INFOONLY option when using GUI.
%
% Revision 1.91  2003/06/06 14:48:50  gadde
% Permute only if we need to.
%
% Revision 1.90  2003/06/06 14:34:35  gadde
% Replace ugly coords loop with cleaner code.
%
% Revision 1.89  2003/06/04 22:25:16  gadde
% Support for merging "split" dimensions.
% Reorder dimensions to 'x', 'y', 'z', 't'.
%
% Revision 1.88  2003/05/30 16:39:11  gadde
% Use BitsAllocated instead of BitDepth (depth may not be a multiple of
% 8 bits).
%
% Revision 1.87  2003/05/30 15:44:30  gadde
% Run GUI when the only argument is '=>INFOONLY'.
% Since we change the input arg array, calculate number of args before
% checking using nargchk.
%
% Revision 1.86  2003/05/30 03:02:29  michelich
% Added ability to chose workspace variable like the old readmr.
%
% Revision 1.85  2003/05/30 02:50:02  michelich
% Moved GUI code from readmrtest.m to readmrtestgui.m
%
% Revision 1.84  2003/05/16 21:58:20  gadde
% Get rid of elemsize info field
%
% Revision 1.83  2003/05/06 18:34:22  michelich
% Added filtering when chosing file.
%
% Revision 1.82  2003/04/18 19:16:06  gadde
% Cache results (file sizes) of directory lookup.  If it works,
% we can get rid of trySpecFlag kludge in getfilesizes.
%
% Revision 1.81  2003/04/18 17:02:43  gadde
% fragsize =  file size minus header size in non-headerless formats.
%
% Revision 1.80  2003/04/18 16:07:24  michelich
% Check that 'Volume' and 'Float' formats read the entire file.
% Added more agressive getfilesizes algorithm using wildcards.
%
% Revision 1.79  2003/04/11 20:40:26  gadde
% Fix error message when encountering an unknown format type.
%
% Revision 1.78  2003/04/11 20:12:59  gadde
% To cut down on redundant code for image formats that have both
% "complete" and "incomplete" access methods, switch first on image
% formats and do the typespec checking within each format along with
% argument checking.
%
% Revision 1.77  2003/04/01 21:19:52  gadde
% Add a missing file separator.
%
% Revision 1.76  2003/04/01 21:15:09  gadde
% Check if multiple given DICOM files "match".
% Put NaN in for info values that are not specified.
%
% Revision 1.75  2003/04/01 18:11:34  michelich
% Add support for =>native return type.
%
% Revision 1.74  2003/03/31 18:57:06  michelich
% Make legacy cannedFormat support case insensitive.
%
% Revision 1.73  2003/03/31 18:23:43  michelich
% Automatically use list of files as 4th dimension for 'Float' format.
% Added dataspec argument checking for 'Float','Volume','Raw' formats.
%
% Revision 1.72  2003/03/31 14:51:13  gadde
% Error if specified array size is too small for amount of data in files.
%
% Revision 1.71  2003/03/31 14:46:40  gadde
% Error if specified array size is too big for amount of data in files.
%
% Revision 1.70  2003/03/28 18:46:59  gadde
% Expunge unnecessary redundancy.
%
% Revision 1.69  2003/03/27 20:50:03  gadde
% Fix wildcards on UNIX -- different values in name field for dir()
% on UNIX and Windows.
%
% Revision 1.68  2003/03/25 15:14:57  gadde
% Windows doesn't return full path in struct returned by dir(), but UNIX does.
%
% Revision 1.67  2003/03/25 14:49:30  gadde
% Fix a path concatenation problem.
%
% Revision 1.66  2003/03/24 23:49:00  michelich
% Add support for multiple files in Analyze7.5_SPM format (files are 4th dimension).
%
% Revision 1.65  2003/03/24 21:20:56  gadde
% Fix coords2page calculation.
%
% Revision 1.64  2003/03/24 19:37:20  michelich
% Get file error message before closing file.
%
% Revision 1.63  2003/03/24 13:50:16  gadde
% Changed name of XIMG format.
%
% Revision 1.62  2003/03/22 14:49:16  gadde
% Support for Signa E*S*I* format
%
% Revision 1.61  2003/03/20 21:57:59  gadde
% On the road to fixing some selector errors...
%
% Revision 1.60  2003/03/20 16:58:23  gadde
% *** empty log message ***
%
% Revision 1.59  2003/03/20 15:38:46  michelich
% Removed remnants of allInOne and startExt options for 'Raw' format.
% Added check for incorrect number of Raw typespec parameters.
% Added check for no matches on wildcard searches.
%
% Revision 1.58  2003/03/17 21:29:39  gadde
% Fix progress bar.
%
% Revision 1.57  2003/03/17 19:19:49  michelich
% Reduce minchunksize to fit a 64x64 slice.
% Use ismember without index output for MATLAB 6.1 & earlier.
%
% Revision 1.56  2003/03/14 21:40:56  michelich
% Bug fix: Prepend path when expanding wildcard filenames.
% Bug fixes & optimizations for getfilesizes().
%
% Revision 1.55  2003/03/14 20:23:00  gadde
% Replace path with pathstr.
%
% Revision 1.54  2003/03/14 19:37:36  gadde
% Add support for turning off progress bar.
% Cut down calls to geturlfromfile.
%
% Revision 1.53  2003/03/14 17:01:24  gadde
% Move file size calculation into function that tries to be smart.
%
% Revision 1.52  2003/03/14 16:15:10  gadde
% Get rid of dimorder for 'Float' and 'Volume'.
% Fix unforunate variable name collision as result of desc/info switch.
% Force specification of all files (wildcards work) for 'Float' and 'Volume'
%  (i.e. no searching of other files by numeric extension).
%
% Revision 1.51  2003/03/13 21:14:05  gadde
% Add wildcard support.
%
% Revision 1.50  2003/03/12 16:34:01  gadde
% Check return value of loadlocation
%
% Revision 1.49  2003/03/12 16:32:19  gadde
% movefile doesn't exist in 6.1
%
% Revision 1.48  2003/03/12 16:15:03  gadde
% Put back try/catch.
%
% Revision 1.47  2003/03/12 15:07:32  gadde
% Changed desc to info.
% Added =>INFOONLY and =>CLEANUP options.
%
% Revision 1.46  2003/02/13 14:19:27  michelich
% Assign output to ans if no outputs requested in command line case.
%
% Revision 1.45  2003/02/13 14:14:37  michelich
% Call FileListPopupMenu_Callback to apply GUI changes when new file chosen.
% Widen buttons.
%
% Revision 1.44  2003/02/13 04:59:48  michelich
% Simplified handling of recent files.
%
% Revision 1.43  2003/02/13 00:10:29  michelich
% Assign output to ans if no outputs requested.
% Better sizing of GUI elements.
% Misc appearence changes in local_initgui.
%
% Revision 1.42  2003/02/12 23:17:01  michelich
% Don't allow okay if inputloc is a directory.
%
% Revision 1.41  2003/02/12 23:03:15  michelich
% Fixed two recent files bugs.
%
% Revision 1.40  2003/02/12 22:54:24  michelich
% Added recent files to GUI.
%
% Revision 1.39  2003/02/12 19:52:31  michelich
% Added callback switchyard & argument handling for full featured GUI.
%
% Revision 1.38  2003/02/10 19:02:27  michelich
% Implement super simple GUI.
%
% Revision 1.37  2003/02/10 18:44:48  gadde
% Sigh, put try/catch back.
%
% Revision 1.36  2003/02/03 17:48:31  gadde
% Changed order of return type argument
%
% Revision 1.35  2003/01/31 21:00:50  gadde
% Update documentation and make chunk selection a little more friendly.
%
% Revision 1.34  2003/01/30 22:01:51  gadde
% Force argument order (and fix some tabs).
%
% Revision 1.33  2003/01/28 21:32:02  gadde
% Get full paths in BASE!
%
% Revision 1.32  2003/01/28 17:11:33  gadde
% Get full paths in BASE?
%
% Revision 1.31  2003/01/27 22:47:10  michelich
% Use pathstr when finding files for allInOne
%
% Revision 1.30  2003/01/27 22:25:06  michelich
% Auto-indented
%
% Revision 1.29  2003/01/27 21:55:50  michelich
% Moved number of arguments checking outside of main try-catch since
% variables used in catch are not initialized.
%
% Revision 1.28  2003/01/27 20:11:41  michelich
% Fixed path and filename generation for allInOne files
%
% Revision 1.27  2003/01/27 18:35:28  gadde
% Fix for older Java (in Matlab 6.1).
%
% Revision 1.26  2003/01/22 16:01:53  gadde
% Add necessary fclose()s.
% Downloading to local file now preserves extension.
% Allow Analyze .hdrs to force download of .img.
%
% Revision 1.25  2003/01/22 15:09:19  gadde
% fclose() fids after we're done with them.
% Delete downloaded files in catch.
%
% Revision 1.24  2003/01/21 21:42:41  gadde
% Support for URLs.
% Sending multiple input DICOM files disables file search.
% Progress bar a little more responsive for multi-file data.
%
% Revision 1.23  2003/01/15 19:25:33  gadde
% DICOM_Dataset not needed anymore because isdicom() now deals with
% pure datasets too.
%
% Revision 1.22  2003/01/15 19:22:21  gadde
% Fix DICOM pathname generation.
%
% Revision 1.21  2003/01/15 17:21:49  gadde
% Reduce check for number of output arguments.
%
% Revision 1.20  2003/01/15 17:18:55  gadde
% Updated comment.
%
% Revision 1.19  2003/01/15 16:49:35  gadde
% Allow specification of return type of data.
%
% Revision 1.18  2003/01/14 23:16:25  gadde
% Get rid of "separate" output arguments.
% Add more DICOM info into header.
%
% Revision 1.17  2003/01/14 19:03:43  gadde
% Allow 'Raw' opt_dimorder to be optional.
%
% Revision 1.16  2003/01/14 16:21:54  gadde
% Add missing semicolon.
%
% Revision 1.15  2003/01/13 22:01:12  gadde
% Random indentation fixes, and now actually use output of rmfield.
%
% Revision 1.14  2003/01/13 21:15:37  gadde
% Some relative path handling fixes.
%
% Revision 1.13  2003/01/13 14:48:48  gadde
% Flag those files that we have detected as DICOM but that MATLAB won't read.
%
% Revision 1.12  2003/01/10 22:44:38  gadde
% Make relative paths work?
%
% Revision 1.11  2003/01/10 15:32:01  gadde
% Changed logical operators from short-circuit to element-wise
%
% Revision 1.10  2003/01/08 22:08:57  michelich
% Vectorized generation of formats structure.
%
% Revision 1.9  2003/01/08 17:22:51  gadde
% Now carries actual header in desc (for later use in writing, perhaps).
%
% Revision 1.8  2003/01/06 20:57:03  gadde
% datarec2mrhdr => datarec2mrdesc
%
% Revision 1.7  2003/01/06 20:54:55  gadde
% hdr => desc
% Moved datarec2mrhdr out.
% Other minor fixes.
%
% Revision 1.6  2002/12/20 19:56:14  gadde
% Need to use .VALUE when getting attributes from xml structs!
%
% Revision 1.5  2002/12/20 19:32:07  gadde
% Easy fixes (!) for selector dimension parsing, numchunks calculation,
% and postselect array issue
%
% Revision 1.4  2002/12/20 18:40:36  gadde
% Uncommented try/catch stuff.
%
% Revision 1.3  2002/12/20 18:38:20  gadde
% Finished support for reading non-allInOne files.
%
% Revision 1.2  2002/12/20 18:14:47  gadde
% Fixed indenting and fixed BXH type and subtype specification
% (also allows 'ascii' as a pixel type)
%
% Revision 1.1  2002/12/20 16:50:41  gadde
% First commit of autodetecting, data-selectable readmr.
%
