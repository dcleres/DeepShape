function mrstruct=createmrstruct(data)
%CREATEMRSTRUCT Create a valid MR struct from a given N-dimensional array
%
%  mrstruct = createmrstruct(data);
%
%  This function assumes data array is in 'x', 'y', 'z', 't' order
%  (fastest-moving dimension to slowest).  Units of spatial dimensions
%  are set to 'mm', and time is 'ms'.
%
% See Also: READMR, WRITEMRTEST

% CVS ID and authorship of this code
% CVSId = '$Id: createmrstruct.m,v 1.13 2005/10/27 15:13:47 gadde Exp $';
% CVSRevision = '$Revision: 1.13 $';
% CVSDate = '$Date: 2005/10/27 15:13:47 $';
% CVSRCSFile = '$RCSfile: createmrstruct.m,v $';

error(nargchk(1,1,nargin));
if ~islogical(data) & ~isnumeric(data)
  error(['Input to createmrstruct must be numeric, found "' class(data) '"']);
end

% Dimension types and units for first 4 dimensions
dimtypes = {'x','y','z','t'};
dimunits = {'mm','mm','mm','ms'};

% Create base info elements
info = [];
info.rawelemtype = class(data);
info.elemtype = class(data);
info.outputelemtype = class(data);
machtype = computer;
if     strmatch(machtype,'PCWIN')
  info.byteorder = 'l';
elseif strmatch(machtype,'LNX86')
  info.byteorder = 'l';
elseif strmatch(machtype,'GLNX86')
  info.byteorder = 'l';
elseif strmatch(machtype,'ALPHA')
  info.byteorder = 'l';
elseif strmatch(machtype,'SOL2')
  info.byteorder = 'b';
elseif strmatch(machtype,'HPUX')
  info.byteorder = 'b';
elseif strmatch(machtype,'HP700')
  info.byteorder = 'b';
elseif strmatch(machtype,'IBM_RS')
  info.byteorder = 'b';
elseif strmatch(machtype,'SGI')
  info.byteorder = 'b';
elseif strmatch(machtype,'MAC')
  info.byteorder = 'b';
else
  warn(['Unrecognized machine type "' machtype '".  Can''t figure out native machine byte order.  Assuming little-endian.']);
  info.byteorder = 'l';
end
info.dimensions = [];  % Set below
info.hdr = [];
info.hdrtype = '';
info.displayname = '';

if strcmp(class(data), 'logical')
  info.rawelemtype = 'uint8';
  info.elemtype = 'uint8';
  info.outputelemtype = 'uint8';
end

ndimsData = ndims(data);
% Generate dimension types and units if data is more than 4-D
if ndimsData > 4
  dimtypes = cat(2,dimtypes,cell(1,ndimsData-4));
  for n = 5:ndimsData, dimtypes{n} = sprintf('dim%d',n); end
  dimunits = cat(2,dimunits,repmat({'unknown'},1,ndimsData-4));
end

% Generate dimensions structures
info.dimensions = struct( ...
  'type', dimtypes(1:ndimsData), ...
  'units', dimunits(1:ndimsData), ...
  'size', num2cell(size(data)), ...
  'origin', NaN, ...
  'gap', NaN, ...
  'spacing', NaN, ...
  'datapoints', {{NaN}}, ...
  'direction', [NaN NaN NaN],...
  'directionprecision', NaN);

mrstruct = [];
mrstruct.info = info;
mrstruct.data = data;

% Modification History:
%
% $Log: createmrstruct.m,v $
% Revision 1.13  2005/10/27 15:13:47  gadde
% Fix to last byte order fix.
%
% Revision 1.12  2005/10/27 15:12:38  gadde
% Choose the right byte order.
%
% Revision 1.11  2005/02/03 16:58:38  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.10  2005/01/21 19:48:30  gadde
% Support logical arrays as input.
%
% Revision 1.9  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.8  2003/10/21 15:34:13  gadde
% Make sure datapoints field is a cell array.
%
% Revision 1.7  2003/09/25 21:00:53  michelich
% Update mrstruct to match readmr.
% Change default hdrtype to 'None'.
%
% Revision 1.6  2003/07/03 20:23:03  gadde
% Use more consistent elemtype description in info by adding
% rawelemtype (input) and outputelemtype (output).
%
% Revision 1.5  2003/06/30 16:54:30  michelich
% Updated for readmr name change.
%
% Revision 1.4  2003/06/25 21:06:56  gadde
% Add precision to direction vectors
%
% Revision 1.3  2003/05/16 22:19:04  michelich
% Vectorized dimensions creation.
% Changed default units for dimensions greater than 4 to unknown.
%
