function info=datarec2mrinfo(datarec)
% DATAREC2MRINFO Convert a BXH datarec structure into a MR descriptor
%
%    info = datarec2mrinfo(datarec);

% CVSId = '$Id: datarec2mrinfo.m,v 1.27 2005/06/22 14:44:38 gadde Exp $';
% CVSRevision = '$Revision: 1.27 $';
% CVSDate = '$Date: 2005/06/22 14:44:38 $';
% CVSRCSFile = '$RCSfile: datarec2mrinfo.m,v $';

typesizes = struct('type', ...
                   {'uchar', 'schar', ...
                    'int8', 'int16', 'int32', 'int64', ...
                    'uint8', 'uint16', 'uint32', 'uint64', ...
                    'single', 'float32', 'double', 'float64'}, ...
                   'size', ...
                   {1, 1, ...
                    1, 2, 4, 8, ...
                    1, 2, 4, 8, ...
                    4, 4, 8, 8 });

lasterr('');
emsg = '';
try
  info = []; % allocate the header

  try
    info.rawelemtype = datarec.elementtype{1}.VALUE;
    info.elemtype = '';
    info.outputelemtype = datarec.elementtype{1}.VALUE;
  catch emsg='Can''t find elementtype!'; error(emsg); end
  
  if strcmpi(info.rawelemtype, 'ascii')
    info.rawelemtype = 'uchar';
    info.outputelemtype = 'uchar';
  end
  
  typesize = typesizes(find(strcmp(info.rawelemtype,{typesizes.type})));
  typesize = typesize.size;

  try info.byteorder = datarec.byteorder{1}.VALUE;
  catch emsg='Can''t find byteorder!'; error(emsg); end
  if strcmp(info.byteorder,'msbfirst')
    info.byteorder = 'b';
  elseif strcmp(info.byteorder,'lsbfirst')
    info.byteorder = 'l';
  else
    emsg='Bad byteorder!'; error(emsg);
  end

  try dimensions = datarec.dimension;
  catch emsg='Can''t find dimensions!'; error(emsg); end
  for dimnum=1:length(dimensions);
    dim = dimensions{dimnum};
    try info.dimensions(dimnum).type = dim.ATTRS.type.VALUE;
    catch emsg='Can''t find dimension type!'; error(emsg); end
    try info.dimensions(dimnum).units = dim.units{1}.VALUE;
    catch info.dimensions(dimnum).units = ''; end
    try info.dimensions(dimnum).size = dim.size{1}.VALUE;
    catch emsg='Can''t find dimension size!'; error(emsg); end
    try info.dimensions(dimnum).outputselect = dim.ATTRS.outputselect.VALUE + 1; % make indexing start at 1
    catch info.dimensions(dimnum).outputselect = NaN; end
    try info.dimensions(dimnum).origin = dim.origin{1}.VALUE;
    catch info.dimensions(dimnum).origin = NaN; end
    try info.dimensions(dimnum).spacing = dim.spacing{1}.VALUE;
    catch info.dimensions(dimnum).spacing = NaN; end
    try info.dimensions(dimnum).gap = dim.gap{1}.VALUE;
    catch info.dimensions(dimnum).gap = NaN; end
    try
      datapoints = dim.datapoints{1};
      if isfield(datapoints, 'value')
        for dpnum=1:length(datapoints.value)
          info.dimensions(dimnum).datapoints{dpnum} = ...
              datapoints.value{1}.VALUE;
        end
      else
        info.dimensions(dimnum).datapoints = num2cell(dim.datapoints{1}.VALUE);
      end
    catch info.dimensions(dimnum).datapoints = { NaN }; end
    try info.dimensions(dimnum).direction = dim.direction{1}.VALUE;
    catch info.dimensions(dimnum).direction = [NaN NaN NaN]; end
    try info.dimensions(dimnum).directionprecision = dim.direction{1}.ATTRS.precision.VALUE;
    catch info.dimensions(dimnum).directionprecision = NaN; end
  end
  
  try filenames = datarec.filename;
  catch emsg='Error getting filename field!'; error(emsg); end
  for n=1:length(datarec.filename);
    try filenames{n} = datarec.filename{n}.VALUE;
    catch emsg='Error getting filename value!'; error(emsg); end
  end
  
  try fpdims = datarec.filenameprintfdimensions;
  catch fpdims = {}; end
  if ~isempty(fpdims) & length(fpdims) > 1
    emsg='More than one "filenameprintfdimensions" field!'; error(emsg);
  end
  
  sizes = [info.dimensions.size];

  % Use filenameprintfdimensions
  if ~isempty(fpdims)
    if length(filenames) > 1
      emsg='Only one filename allowed when using filenameprintfdimensions!'; error(emsg);
    end
    template = filenames{1};
    
    try fpdims = fpdims{1}.VALUE;
    catch emsg='Error getting filenameprintfdimensions value!'; error(emsg); end
    try fporigins = datarec.filenameprintforigins;
    catch fporigins = zeros(length(fpdims)); end
    if isempty(fporigins)
      fporigins = repmat([0], [1 length(fpdims)]);
    else
      if length(fporigins) > 1
        emsg='More than one "filenameprintforigins" field!'; error(emsg);
      end
      try fporigins = fporigins{1}.VALUE;
      catch emsg='Error getting filenameprintforigins value!'; error(emsg); end
    end
    
    if length(fpdims) ~= length(fporigins)
      emsg=['Number of filenameprintfdimensions must equal number of filenameprintforigins']; error(emsg);
    end
    if max(fpdims) > length(info.dimensions)
      emsg=sprintf('filenameprintfdimensions needs dimension %d but there are only %d dimensions!', ...
        max(fpdims),length(info.dimensions)); error(emsg);
    end

    sortedfpdims = sort(fpdims);

    % step = how many elements to skip for each file
    if sortedfpdims(1) == 1
      step = 1;
    else
      step = prod(sizes(1:sortedfpdims(1)-1));
    end
    
    filenames = {};
    for elemnum=0:step:prod(sizes)-1
      stepnum = elemnum/step;
      coords = [];
      for dimnum=1:length(sortedfpdims)
        coords(sortedfpdims(dimnum)) = mod(stepnum, sizes(sortedfpdims(dimnum)));
        stepnum = floor(stepnum / sizes(sortedfpdims(dimnum)));
      end
      fillers = coords(fpdims) + fporigins;
      filenames{length(filenames)+1} = sprintf(template, fillers(:));
    end
  end
  
  numfrags = 0;
  try
    offsetcells = datarec.fileoffset;
    if length(offsetcells) ~= 1 & length(offsetcells) ~= length(filenames)
      emsg='Number of fileoffset elements must be 1 or same as number of filenames'; error(emsg);
    end
    if length(offsetcells)==1
      for i=2:length(filenames)
        offsetcells{i} = offsetcells{1};
      end
    end
    for i=1:length(filenames)
      fileoffsets{i} = offsetcells{i}.VALUE;
      numfrags = numfrags + length(fileoffsets{i});
    end
  catch
    if ~isempty(emsg), error(emsg); end
    numfrags = length(filenames);
    for i=1:length(filenames)
      fileoffsets{i} = 0;
    end
  end
  
  recordsizes = {};
  try
    sizecells = datarec.filerecordsize;
    if length(sizecells) ~= 1 & length(sizecells) ~= length(filenames)
      emsg='Number of filerecordsizes must be 1 or same as number of filenames'; error(emsg);
    end
    if length(sizecells) == 1
      for i=2:length(filenames)
        sizecells{i} = sizecells{1};
      end
    end
    for i=1:length(filenames)
      if length(sizecells{i}.VALUE) ~= 1 & ...
            length(sizecells{i}.VALUE) ~= length(fileoffsets{i})
        emsg='Number of filerecordsizes must be 1 or match number of fileoffsets for each filename!'; error(emsg);
      end
      if length(sizecells{i}.VALUE) == 1
        for j=2:length(fileoffsets{i})
          sizecells{i}.VALUE(j) = sizecells{i}.VALUE(1);
        end
      end
      recordsizes{i} = sizecells{i}.VALUE;
    end
  catch
    if ~isempty(emsg), error(emsg), end
    for i=1:length(filenames)
      for j=1:length(fileoffsets{i})
        recordsizes{i}(j) = typesize * prod(sizes) / numfrags;
      end
    end
  end

  fragsPerFile = cellfun('length', fileoffsets);
  info.frags = struct('filenames', {cell(1,sum(fragsPerFile))}, ...
    'fileoffsets', [fileoffsets{:}], ...
    'fragsizes', [recordsizes{:}]);
  ind = 1;
  for filenum=1:length(filenames)
    info.frags.filenames(ind:(ind+fragsPerFile(filenum)-1)) = filenames(filenum);
    ind = ind + fragsPerFile(filenum);
  end
  
  names = fieldnames(datarec);
  for namenum = 1:length(names)
    name = names{namenum};
    parsednames = { 'elementtype', 'byteorder', 'dimension', ...
		    'filename', 'orientation', ...
		    'filenameprintfdimensions', 'filenameprintforigins', ...
		    'fileoffset', 'filerecordsize', ...
		    'CHILDRANK', 'VALUECHILDRANK', ...
                    'BASE', ...
                    'NAMESPACE', 'NSDEFS', 'ATTRS', 'PINSTS', ...
		    'COMMENTS', 'VALUE' };
    if any(strmatch(name, parsednames, 'exact')), continue; end
    eval(['info.unparsed.' name ' = datarec.' name ';']);
  end
    
catch
  if isempty(emsg)
    if isempty(lasterr)
      emsg='An unidentified error occurred!';
    else
      emsg=lasterr;
    end
  end
  error(emsg);
end

% Modification History:
%
% $Log: datarec2mrinfo.m,v $
% Revision 1.27  2005/06/22 14:44:38  gadde
% Fix index increment bug
%
% Revision 1.26  2005/06/21 21:25:58  michelich
% Preallocate and vectorize code to generate frags.  Approx 7 times faster testing with 8000 files.
%
% Revision 1.25  2005/06/17 15:22:01  gadde
% Move from array of frag structures to frag list structure of arrays.
%
% Revision 1.24  2005/02/03 16:58:38  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.23  2004/09/23 14:59:12  gadde
% Standardize dimension field list and order.
%
% Revision 1.22  2004/01/22 16:47:09  gadde
% Check rawelemtype instead of elemtype (which is always '').
%
% Revision 1.21  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.20  2003/10/22 15:31:36  gadde
% Add support for outputselect attribute
%
% Revision 1.19  2003/08/01 21:39:11  michelich
% Check that all dimensions in filenameprintfdimensions exist.
%
% Revision 1.18  2003/07/03 20:22:01  gadde
% Use more consistent elemtype description in info by adding
% rawelemtype (input) and outputelemtype (output).
%
% Revision 1.17  2003/06/25 20:59:50  gadde
% add precision attribute to direction vectors (missing means infinite)
%
% Revision 1.16  2003/06/18 18:36:47  gadde
% Use empty character string for units.
%
% Revision 1.15  2003/06/18 18:25:08  gadde
% Make empty units if we don't know them.
%
% Revision 1.14  2003/06/06 14:19:34  gadde
% Make datapoints a cell array (to allow for encapsulated "value" elements).
%
% Revision 1.13  2003/06/04 22:31:52  gadde
% Untested (!) fix in case of missing fprintforigins field.
%
% Revision 1.12  2003/05/16 21:58:33  gadde
% Get rid of elemsize info field.
%
% Revision 1.11  2003/05/16 21:00:12  gadde
% Even though it doesn't matter, change last 'desc's to 'info's.
%
% Revision 1.10  2003/04/16 15:07:49  gadde
% Use new "CHILDRANK" field to do what "ORDER" did before.
% Now XML structures are much more robust when modified
% (e.g. adding/deleting elements).
%
% Revision 1.9  2003/04/01 21:15:53  gadde
% Use NaN to represent unspecified values.
%
% Revision 1.8  2003/03/31 20:51:15  gadde
% Finish desc->info changes.
% Remove informative orientation element.
%
% Revision 1.7  2003/01/22 22:12:44  gadde
% Don't assume that dimension structures all have the same fields.
%
% Revision 1.6  2003/01/14 21:05:21  gadde
% Oops, dynamic field names don't work in 6.1.
%
% Revision 1.5  2003/01/14 16:43:10  gadde
% Ignore reserved fields for 'unparsed' section.
%
% Revision 1.4  2003/01/14 16:15:17  gadde
% Keep unparsed fields.
%
% Revision 1.3  2003/01/14 16:14:41  gadde
% Replace variable names hdr* with desc*.
%
% Revision 1.2  2003/01/10 15:32:00  gadde
% Changed logical operators from short-circuit to element-wise
%
% Revision 1.1  2003/01/06 20:57:26  gadde
% Moved out of readmrtest.m
%
