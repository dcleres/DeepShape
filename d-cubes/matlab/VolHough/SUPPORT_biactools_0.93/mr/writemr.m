function varargout=writemr(varargin)
%WRITEMR Write MR images from structure.
%
%   writemr(mrstruct, filename, outputtype);
%   writemr(mrstruct, filename, outputtype, modifiers);
%   writemr(mrstruct, filename, {outputtype, outputopts...});
%   writemr(mrstruct, filename, {outputtype, outputopts...}, modifiers);
%
%   WRITEMR takes an mr struct and writes it out to file(s)
%   (filename).  The mrstruct is of the type returned by READMR.
%   The output format is, by default, the format specified in the
%   mrstruct, but this and other parameters can be changed using
%   further output options (outputopts) which can be one of the following:
%     {'BXH', datarecType, datarecSubtype, datafilename}
%        -- BXH header will be written to filename, and image data will
%           be written to datafilename.  If datafilename does not exist,
%           it will be constructed from filename with a '.data' extension.
%           mrstruct.info.outputelemtype used as output precision.
%        -- datarecType is the BXH data record type to use (typically = 'image')
%        -- datarecSubtype is the BXH data record subtype to use (typically = '')
%     {'Float'}
%        -- image data written as float32, one-file-per-volume
%     {'Volume'}
%        -- image data written as int16, one-file-per-volume
%     {'RawVolumes', opt_outputPixelType}
%        -- image data will be written to filename, one-file-per-volume
%     {'Raw', opt_outputPixelType}
%        -- image data will be written to filename
%        -- opt_outputPixelType is a string specifying the precision to
%           use when writing the output data (e.g. 'uint8', 'int16',
%           'float32', etc).   If not specified, the value in
%           mrstruct.info.outputelemtype will be used.
%
%   For one-file-per-volume formats, the filename may include a wildcard;
%   the volume number will be inserted there.  Otherwise, if there is more
%   than one volume, the volume number is appended to the filename.  The
%   volume number is 0-padded with enought digits (4 minimum) to sort the
%   filenames alphanumerically.
%
%   If the output type is not explicitly 'BXH', an additional BXH file
%   will, by default, be written to accompany the output file(s).  The
%   name of this BXH file will be determined from the filename (but with
%   a .bxh extension).
%
%   The last argument may be a semicolon-separated list of modifiers.
%   If one of the modifiers is 'OVERWRITE', it will blatantly overwrite
%   the file "filename" (and other output files) if they exist.  Beware!
%   If one of the modifiers is 'NOBXH', the additional BXH file
%   written to encapsulate the output data will not be written.
%   If one of the modifiers is 'NODATA', the data file(s)
%   will not be written (BXH file will be written unless otherwise specified).
%   Writing to BXH from another input format may be a lossy process;
%   original headers are not preserved, and only some of the header
%   info might be extracted into the BXH header during conversion.
%
% Examples:
% % Write data to a single file (precision is mrstruct.info.outputelemtype)
% writemr(mrstruct, 'V.bxh', 'BXH');                      % Data in V.data
% writemr(mrstruct, 'V.bxh', {'BXH','image','','V.img'}); % Data in V.img
%
% % Write data to a single file (V.img)
% writemr(mrstruct, 'V.img', {'Raw','float32'}); % single precision float
% writemr(mrstruct, 'V.img', {'Raw','int16'});   % signed 16-bit integer
% writemr(mrstruct, 'V.img', {'Raw','uint8'});   % unsigned 8-bit integer
%
% % Write each volume to a separate file (V0001.img, V0002.img, etc)
% writemr(mrstruct, 'V*.img', 'Float');          % single precision float
% writemr(mrstruct, 'V*.img', 'Volume');         % signed 16-bit integer
% writemr(mrstruct, 'V*.img', {'RawVolumes','int8'}); % signed 8-bit integer
%
% (A BXH file named V.bxh will be created by each example)
%
% See Also: READMR, CREATEMRSTRUCT

% ------------------- Note on backwards compatibility -------------------
% WRITEMR also supports the following "old-style" arguments for backwards
%   compatibility.
%
%   writemr(fName,srs);
%   writemr(fName,srs,cannedFormat);
%
%   fName is the full path and name of the file to write the MR data to.
%   srs is an x by y by z array of the MR data.
%     Also allows x by y by z by t array.
%   cannedFormat is either 'volume' or 'float' to match the formats
%     read by readmr.  Default is 'volume'.
% ----------------- End: Note on backwards compatibility -----------------

% CVSId = '$Id: writemr.m,v 1.32 2005/06/16 23:09:25 michelich Exp $';
CVSRevision = '$Revision: 1.32 $';
% CVSDate = '$Date: 2005/06/16 23:09:25 $';
% CVSRCSFile = '$RCSfile: writemr.m,v $';

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

if nargout > 0
  error('writemr does not support any output arguments.');
end
if nargin < 2, error('Function requires at least two arguments'); end

if ischar(varargin{1})
  % old-style writemr
  error(nargchk(2,3,nargin));
  fName = varargin{1};
  if nargin<3,
    cannedFormat='volume';
  else
    cannedFormat = varargin{3};
  end
  if ~strcmpi(cannedFormat,'volume') & ~strcmpi(cannedFormat,'float')
    emsg=sprintf('Invalid file format "%s" specified for writing "%s".',cannedFormat,fName); error(emsg);
  end
  % Make sure that they are not passing a mrstruct using the old mode.
  if ~isnumeric(varargin{2}) & ~islogical(varargin{2})
    emsg=['Second argument must be a numeric or logical array ' ...
      'when using writemr backwards compatibility mode']; error(emsg);
  end
  [fid emsg]=fopen(fName,'w','l');
  if fid==-1
    if strcmpi(emsg,'Sorry. No help in figuring out the problem . . .')
      emsg=sprintf('Cannot open file "%s" for writing. No such path? No permission? No memory?',fName);
    end
    error(emsg);
  end
  if strcmpi(cannedFormat,'volume')
    % fwrite fixing/rounding to integer types changed between Matlab 6 and 7.
    % Round before sending to fwrite to standardize.
    inclass = class(varargin{2});
    matlabvers = str2double(strtok(strtok(version),'.'));
    if matlabvers < 7 & ...
        (strcmp(inclass, 'double') | strcmp(inclass, 'single'))
      numitems = prod(size(varargin{2}));
      issingle = isa(varargin{2}, 'single');
      % round in chunks of 1 million items
      chunksize = 2^20;
      for i = 1:chunksize:numitems
        i2 = i + chunksize - 1;
        if i2 > numitems, i2 = numitems; end
        if issingle
          varargin{2}(i:i2) = single(round(double(varargin{2}(i:i2))));
        else
          varargin{2}(i:i2) = round(varargin{2}(i:i2));
        end
      end
    end
    count=fwrite(fid,varargin{2},'int16');
  elseif strcmpi(cannedFormat,'float')
    count=fwrite(fid,varargin{2},'float32');
  end
  if count~=prod(size(varargin{2}))
    fclose(fid);
    error(sprintf('Unable to write entire file "%s"!',fName));
  end
  fclose(fid);
  return
end

args = varargin;

if isnumeric(args{1})
  error(sprintf('First argument must be an MR struct, not a numeric array!\nCreate an MR struct using CREATEMRSTRUCT.'));
elseif ~isstruct(args{1})
  error('First argument must be an MR struct!');
end
if ~ischar(args{2})
  error('Second argument must be a filename!');
end

overwrite = 0;
nobxh = 0;
nodata = 0;
bxhaddtoexisting = 0;
if ischar(args{end})
  foundmod = 0;
  mods = splitstr(args{end}, ';');
  for i = 1:length(mods)
    if strcmp(mods{i}, 'OVERWRITE')
      overwrite = 1;
      foundmod = 1;
    end
    if strcmp(mods{i}, 'NOBXH')
      nobxh = 1;
      foundmod = 1;
    end
    if strcmp(mods{i}, 'NODATA')
      nodata = 1;
      foundmod = 1;
    end
  end
  if foundmod
    args(end) = [];
  end
end

data = [];
info = [];
mrstruct = args{1};
if ~nodata & ~isfield(mrstruct, 'data')
  error('There is no actual data in this mrstruct');
end
info = mrstruct.info;
args(1) = [];
frags = [];
bxhtype = 'image';
bxhsubtype = '';

if length(args) < 1, error('Error parsing arguments!'); end


if ~nodata
  infosizes = [info.dimensions.size];
  while length(infosizes) > 1 & infosizes(end) == 1
    infosizes(end) = [];
  end
  if (length(infosizes) ~= ndims(mrstruct.data) | ...
      any(infosizes ~= size(mrstruct.data)))
    error('Dimensions in mrstruct.info do not match size of mrstruct.data!');
  end
end

filename = args{1};
args(1) = [];

outputopts = {};
if length(args) > 0
  if length(args) == 1 & ischar(args{1})
    % single string
    outputopts = args;
  elseif ~iscell(args{1})
    warning(sprintf('writemr now prefers output type and opts to be in a cell array --\nthe old way is deprecated.  Continuing anyway.'));
    outputopts = args;
  else
    outputopts = args{1};
  end
end

inputformat = info.hdrtype;
outputformat = '';
if length(outputopts) == 0
  outputformat = inputformat;
else
  outputformat = outputopts{1};
  outputopts = {outputopts{2:end}};
end

% do argument checking
if strcmp('Raw', outputformat)
  if length(outputopts) > 1
    error('Output format "Raw" accepts at most one output option.');
  end
  if any(filename == '*')
    error('Wildcards not allowed in output filename for ''Raw'' format');
  end
elseif strcmp('Float', outputformat) | ...
    strcmp('Volume', outputformat) | ...
    strcmp('RawVolumes', outputformat)
  if strcmp('RawVolumes', outputformat)
    if length(outputopts) > 1
      error(sprintf('Output format ''%s'' should have at most one option, pixelType.', outputformat));
    end
  else
    if length(outputopts) > 0
      error(sprintf('Output format ''%s'' should have no further options.', outputformat));
    end
  end
elseif strcmp('BXH', outputformat)
  if length(outputopts) > 3
    error('Output format "BXH" accepts a maximum of three output options.');
  end
end

% figure out input and output types for data items
if isfield(info, 'outputelemtype')
  outclass = info.outputelemtype;
else
  outclass = info.elemtype;
end
if strcmp('Raw', outputformat)
  if length(outputopts) > 0
    outclass = outputopts{1};
  end
elseif strcmp('Float', outputformat) | ...
    strcmp('Volume', outputformat) | ...
    strcmp('RawVolumes', outputformat)
  if strcmp(outputformat, 'Volume')
    outclass = 'int16';
  elseif strcmp(outputformat, 'Float')
    outclass = 'float32';
  elseif strcmp(outputformat, 'RawVolumes')
    if length(outputopts) > 0
      outclass = outputopts{1};
    end
  end
elseif strcmp('BXH', outputformat)
  if isfield(info, 'outputelemtype')
    outclass = info.outputelemtype;
  else
    outclass = info.elemtype;
  end
end
% Set output element type for BXH file.
info.outputelemtype = outclass;

% fwrite fixing/rounding to integer types changed between Matlab 6 and 7.
% Round before sending to fwrite to standardize if Matlab version < 7.
if ~nodata
  inclass = class(mrstruct.data);
  matlabvers = str2double(strtok(strtok(version),'.'));
  if matlabvers < 7 & ...
      (strncmp(outclass, 'int', 3) | strncmp(outclass, 'uint', 4)) & ...
      (strcmp(inclass, 'double') | strcmp(inclass, 'single'))
    numitems = prod(size(mrstruct.data));
    issingle = isa(mrstruct.data, 'single');
    % round in chunks of 1 million items
    chunksize = 2^20;
    for i = 1:chunksize:numitems
      i2 = i + chunksize - 1;
      if i2 > numitems, i2 = numitems; end
      if issingle
        mrstruct.data(i:i2) = single(round(double(mrstruct.data(i:i2))));
      else
        mrstruct.data(i:i2) = round(mrstruct.data(i:i2));
      end
    end
  end
end

if strcmp('Raw', outputformat)
  fullfilename = filename;
  if isrelpath(filename)
    fullfilename = [pwd filesep filename];
  end
  if ~nodata
    if exist(fullfilename, 'file') & ~overwrite
      emsg=sprintf('Output file "%s" exists.', filename); error(emsg);
    end
    [fid, emsg] = fopen(filename, 'w', info.byteorder);
    if fid == -1, error(emsg); end
    count = fwrite(fid, mrstruct.data, outclass);
    fclose(fid);
    if count~=prod(size(mrstruct.data))
      error(sprintf('Unable to write entire file "%s"!',filename));
    end
  end

  % set up frags for BXH output if needed
  frags(1).filename = fullfilename;
  frags(1).fileoffset = NaN;
  frags(1).fragsize = NaN;

elseif strcmp('Float', outputformat) | ...
    strcmp('Volume', outputformat) | ...
    strcmp('RawVolumes', outputformat)
  fullfilename = filename;
  if isrelpath(filename)
    fullfilename = [pwd filesep filename];
  end

  sizes = [info.dimensions.size];
  if length(sizes) < 4
    sizes(end+1:4) = 1;
  end
  sizes = [sizes(1) sizes(2) sizes(3) prod(sizes(4:end))];
  if ~nodata
    mrstruct.data = reshape(mrstruct.data, sizes);
  end
  digitspec = ['%0' num2str(max([(floor(log10(sizes(4))) + 1), 4])) 'd'];
  for vnum = 1:sizes(4)
    [pathstr, name, ext, ver] = fileparts(fullfilename);
    if length(findstr(name, '*')) > 1
      emsg=sprintf('Output file "%s" has more than one wildcard!', fullfilename); error(emsg);
    elseif ~isempty(findstr(name, '*'))
      name = sprintf(strrep(strrep(name,'*',digitspec),'\','\\'),vnum);
    else
      % User didn't specify where to put the volume number.
      % Append it to the end if there is more than one volume.
      if sizes(4) ~= 1
        name = [name ext ver];
        ext = sprintf(digitspec,vnum);
        ver = '';
      end
    end
    volfilename = fullfile(pathstr,[name ext ver]);

    if ~nodata
      if exist(volfilename, 'file') & ~overwrite
        emsg=sprintf('Output file "%s" exists.', volfilename); error(emsg);
      end
      [fid, emsg] = fopen(volfilename, 'w', info.byteorder);
      if fid == -1, error(emsg); end
      vol = mrstruct.data(:,:,:,vnum);
      count = fwrite(fid, vol, outclass);
      fclose(fid);
      if count~=prod(size(vol))
        error(sprintf('Unable to write entire file "%s"!',volfilename));
      end
    end

    % set up frags for BXH output if needed
    fragnum = length(frags) + 1;
    frags(fragnum).filename = volfilename;
    frags(fragnum).fileoffset = NaN;
    frags(fragnum).fragsize = NaN;
  end

elseif strcmp('BXH', outputformat)
  if length(outputopts) >= 1
    bxhtype = outputopts{1};
    if length(outputopts) >= 2
      bxhsubtype = outputopts{2};
    end
  end

  [pathstr, name, ext, ver] = fileparts(filename);
  fulldatafilename = '';
  if length(outputopts) >= 3
    fulldatafilename = outputopts{3};
  else
    fulldatafilename = fullfile(pathstr, [name '.data' ver]);
  end
  [datapathstr, dataname, dataext, dataver] = fileparts(fulldatafilename);

  if ~nodata
    if exist(fulldatafilename, 'file') & ~overwrite
      emsg=sprintf('Output data file "%s" exists.', fulldatafilename); error(emsg);
    end

    [fid, emsg] = fopen(fulldatafilename, 'w', info.byteorder);
    if fid == -1, error(emsg); end
    count = fwrite(fid, mrstruct.data, outclass);
    fclose(fid);
    if count~=prod(size(mrstruct.data))
      error(sprintf('Unable to write entire file "%s"!',fulldatafilename));
    end
  end

  % set up frags for BXH output
  frags(1).filename = fulldatafilename;
  frags(1).fileoffset = NaN;
  frags(1).fragsize = NaN;
else
  error('Only BXH, Float, Volume, Raw, and RawVolumes output formats are supported!');
end

% Output BXH header
if ~nobxh | strcmp('BXH', outputformat)
  inhdr = [];
  if strcmp('BXH', inputformat)
    inhdr = info.hdr;
  else
    newmrstruct = convertmrstructtobxh(mrstruct);
    inhdr = newmrstruct.info.hdr;
  end

  fullbxhfilename = filename;
  if isrelpath(filename)
    fullbxhfilename = [pwd filesep filename];
  end

  % add .bxh extension if output BXH is created automatically
  % (and make sure it doesn't have extension already)
  [bxhpathstr, bxhname, bxhext, bxhver] = fileparts(fullbxhfilename);
  bxhname = strrep(bxhname, '*', '');
  if ~strcmp('BXH', outputformat)
    if strcmp(bxhext, '.bxh')
      error('Output data file already has .bxh extension, can''t figure out what name to give to BXH file!');
    end
    bxhext = '.bxh';
  end
  fullbxhfilename = fullfile(bxhpathstr, [bxhname bxhext bxhver]);

  % make frag filenames relative to BXH file if in same directory
  for i = 1:length(frags)
    if isrelpath(frags(i).filename)
      frags(i).filename = [pwd filesep frags(i).filename];
    end
    [fragpathstr, fragname, fragext, fragver] = fileparts(frags(i).filename);
    if strcmp(fragpathstr, bxhpathstr)
      frags(i).filename = [fragname fragext fragver];
    end
  end

  % add correct frag offsets and sizes
  typesize = typesizes(find(strcmp(outclass,{typesizes.type})));
  elemsize = typesize.size;
  sizes = [info.dimensions.size];
  if length(sizes) < 3, sizes(end+1:3) = 1; end
  if length(frags) > 1
    % Assume one volume per file if more than one frag
    fragsize = prod(sizes(1:3)) * elemsize;
  else
    fragsize = prod(sizes) * elemsize;
  end
  for i = 1:length(frags)
    frags(i).fileoffset = 0;
    frags(i).fragsize = fragsize;
  end

  % add frags to datarec
  if isfield(info, 'frags')
    info = rmfield(info, 'frags');
  end
  info.frags = frags;

  % create output header
  outhdr = inhdr;
  numdatarecs = 0;

  % if output file exists and we are adding to it, use the existing
  % file as a template for output header
  if exist(fullbxhfilename, 'file')
    if bxhaddtoexisting
      outhdr = readbxhhdr(fullbxhfilename);
      if isfield(outhdr.bxh{1}, 'datarec')
        numdatarecs = length(outhdr.bxh{1}.datarec);
      end
      for datarecnum = 1:numdatarecs
        datarec = outhdr.bxh{1}.datarec{datarecnum};
        if strcmp(datarec.ATTRS.type.VALUE, bxhtype) & ...
            ((isfield(datarec.ATTRS, 'subtype') & ...
            strcmp(datarec.ATTRS.subtype.VALUE, bxhsubtype)) | ...
            (~isfield(datarec.ATTRS, 'subtype') & ...
            (strcmp('0', bxhsubtype) | isempty(bxhsubtype))))
          if overwrite
            % delete this datarec (will be replaced later)
            outhdr.bxh{1}.datarec(datarecnum) = [];
            numdatarecs = numdatarecs - 1;
          else
            emsg = sprintf('Type/subtype "%s"/"%s" already exists in output file "%s".', bxhtype, bxhsubtype, fullbxhfilename); error(emsg);
          end
        end
      end

      % XXX TODO: validate that all appropriate in/out info is the same

    elseif ~overwrite
      error(sprintf('Output BXH file %s exists!', fullbxhfilename));
    end
  end

  % add datarec
  if isempty(bxhsubtype)
    newdatarec = mrinfo2datarec(info, bxhtype);
  else
    newdatarec = mrinfo2datarec(info, bxhtype, bxhsubtype);
  end
  outhdr.bxh{1}.datarec{numdatarecs+1} = newdatarec;

  % add a history entry
  if ~isfield(outhdr.bxh{1}, 'history')
    outhdr.bxh{1}(1).history{1}(1).entry = {};
  elseif ~isfield(outhdr.bxh{1}.history{end}, 'entry')
    outhdr.bxh{1}.history{end}(1).entry = {};
  end
  newhistentry = [];
  newhistentry.date{1}.VALUE = datestr(now, 31);
  newhistentry.description{1}.VALUE = sprintf('Written by writemr %s', CVSRevision(2:end-1));
  outhdr.bxh{1}.history{end}.entry{end+1} = newhistentry;

  writexml(outhdr, fullbxhfilename);
end

% $Log: writemr.m,v $
% Revision 1.32  2005/06/16 23:09:25  michelich
% Bug Fix: When using NODATA option, do not attempt to round data.
%
% Revision 1.31  2005/06/15 23:20:04  michelich
% Bug Fix: When using NODATA option with one volume per file output, the
%   filerecordsize was incorrectly set to zero.  Use info struct to determine
%   dimensions instead of data field.
% Removed unnecessary deal().
%
% Revision 1.30  2005/06/15 18:44:31  michelich
% Remove main try-catch block since there is no progress bar to close.
%
% Revision 1.29  2005/03/30 23:16:03  michelich
% Added missing semicolon.
%
% Revision 1.28  2005/02/16 02:54:55  michelich
% Whitespace correction.
%
% Revision 1.27  2005/02/16 02:53:45  michelich
% Use more robust version parsing code.
%
% Revision 1.26  2005/02/03 16:58:45  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.25  2004/11/04 01:32:08  michelich
% Bug Fix: Fix element type in BXH file.
%
% Revision 1.24  2004/10/27 17:08:19  gadde
% Push replicated rounding code to single common area.
%
% Revision 1.23  2004/10/26 23:56:51  gadde
% Fix version checking logic.
%
% Revision 1.22  2004/10/26 23:53:53  gadde
% Only do explicit rounding if version is <= 6.
%
% Revision 1.21  2004/10/26 23:47:22  gadde
% Minor indexing fix.
%
% Revision 1.20  2004/10/26 21:54:37  gadde
% Round before fwrite if writing floating-point data as integer data,
% to standardize fwrite behavior between Matlab 6 (fix) and 7 (round).
%
% Revision 1.19  2004/09/24 19:18:24  gadde
% Fix frag size when there are multiple output data files.
%
% Revision 1.18  2004/05/11 12:33:20  gadde
% Be a little more strict about putting fileoffset/fragsize in.
%
% Revision 1.17  2004/05/06 15:57:38  michelich
% Replace remaining strfind's.
%
% Revision 1.16  2004/05/06 15:15:35  gadde
% Remove all dependencies on ispc and nargoutchk (for compatibility
% with Matlab 5.3).
%
% Revision 1.15  2003/11/17 16:28:46  michelich
% Bug Fix: Update info structure when opt_outputPixelType specified for Raw.
%
% Revision 1.14  2003/11/16 19:00:57  michelich
% Added descriptions of outputopts and examples.
%
% Revision 1.13  2003/10/27 16:24:07  gadde
% If info.dimensions has trailing singleton dimensions, don't use them
% in size validation.
%
% Revision 1.12  2003/10/24 02:30:15  michelich
% Typo fix.
%
% Revision 1.11  2003/10/23 18:20:05  gadde
% Fixes from Jimmy to support mrstructs without data.
%
% Revision 1.10  2003/10/22 18:59:05  gadde
% Add revision to output.
%
% Revision 1.9  2003/10/22 15:54:40  gadde
% Make some CVS info accessible through variables
%
% Revision 1.8  2003/10/21 17:08:26  gadde
% Add NODATA option.
%
% Revision 1.7  2003/10/20 17:16:29  gadde
% More detailed error message for case when user sends a numerica array as
% first argument.
%
% Revision 1.6  2003/10/15 15:27:28  michelich
% Check that dimensions match size of data separately on each dimension.
%
% Revision 1.5  2003/10/15 15:12:46  gadde
% Check that dimensions match size of data.
% Also, avoid a copy by using mrstruct.data directly.
%
% Revision 1.4  2003/09/22 17:17:06  gadde
% move AUTOGEN removal to readbxhhdr
%
% Revision 1.3  2003/09/05 15:01:42  michelich
% Updated documentation and messages for name change.
%
% Revision 1.2  2003/08/25 20:35:57  gadde
% Renaming writemrtest to writemr
%
% Revision 1.31  2003/08/25 17:19:16  gadde
% Check for wildcard in single output filename.
%
% Revision 1.30  2003/08/25 16:49:41  gadde
% Allow pixel type to be optional in RawVolumes (already was in Raw, just
% document that).
%
% Revision 1.29  2003/08/08 13:49:19  gadde
% Fix relative filename construction.
%
% Revision 1.28  2003/07/25 19:37:30  michelich
% Minor fix in minimum padding calculation.
% Don't append volume number if there is only one volume & no wildcard.
%
% Revision 1.27  2003/07/25 19:09:27  gadde
% Make volume numbers at least 4 digits wide.
%
% Revision 1.26  2003/07/25 18:57:24  gadde
% Allow for wildcards in output filename (for "volume formats").
% Pad volume number with only as many '0' digits as needed.
%
% Revision 1.25  2003/07/25 17:06:26  gadde
% Add RawVolumes format.
%
% Revision 1.24  2003/07/25 16:58:32  gadde
% Allow Float and Volume data types as output.
%
% Revision 1.23  2003/07/24 20:39:42  michelich
% Fixed handling of old-style default cannot format.
% Added check for mrstruct in old-style support.
%
% Revision 1.22  2003/07/24 19:26:13  gadde
% Add backward-compatibility.
% Change outputopts to a cell array, warn if not in new form.
% More error messages for malformed input arguments.
% Automatically output a BXH header for all output types, except if
% new NOBXH modifier is given.
%
% Revision 1.21  2003/07/03 20:22:41  gadde
% Use more consistent elemtype description in info by adding
% rawelemtype (input) and outputelemtype (output).
%
% Revision 1.20  2003/06/30 16:54:31  michelich
% Updated for readmr name change.
%
% Revision 1.19  2003/06/04 22:26:41  gadde
% Don't try to add to existing BXH file (can add as argument later)
%
% Revision 1.18  2003/05/30 14:36:14  gadde
% Fix relative pathnames when determining pathnames for data files.
%
% Revision 1.17  2003/05/29 20:07:13  gadde
% Write .data files to the same directory as .bxh file.
%
% Revision 1.16  2003/04/18 16:34:53  gadde
% New COMMENT structure.
%
% Revision 1.15  2003/04/16 15:08:27  gadde
% Use new "CHILDRANK" field to do what "ORDER" did before.
% Now XML structures are much more robust when modified
% (e.g. adding/deleting elements).
%
% Revision 1.14  2003/04/15 16:22:50  gadde
% Write relative filenames if data filename is automatically generated.
%
% Revision 1.13  2003/04/11 21:08:31  michelich
% Change double curly braces to parentheses
%
% Revision 1.12  2003/04/11 19:48:23  gadde
% Add some missing curly braces, and remove unnecessary find().  Thanks Josh!
%
% Revision 1.11  2003/04/11 19:38:36  gadde
% Oops, don't modify varargin
%
% Revision 1.10  2003/04/10 20:30:00  gadde
% Fix argument list.
%
% Revision 1.9  2003/04/10 20:28:10  gadde
% Add overwrite option.
%
% Revision 1.8  2003/04/01 19:02:06  gadde
% Fix tabs and allow for empty datarecs.
%
% Revision 1.7  2003/03/28 18:45:27  gadde
% Allow writing (sparse) BXH files from other formats.
% Fix writing to existing BXH files.
%
% Revision 1.6  2003/03/27 16:26:33  michelich
% Changed desc to info.
%
% Revision 1.5  2003/03/12 15:08:11  gadde
% Changed desc to info.
%
% Revision 1.4  2003/01/15 15:09:29  gadde
% Get rid of separate data/desc arguments.
%
% Revision 1.3  2003/01/14 21:06:43  gadde
% Missed a short-circuit logical -- fixed.
%
% Revision 1.2  2003/01/14 19:40:08  gadde
% Fixed comment.
%
% Revision 1.1  2003/01/14 19:39:54  gadde
% Initial import.
%
