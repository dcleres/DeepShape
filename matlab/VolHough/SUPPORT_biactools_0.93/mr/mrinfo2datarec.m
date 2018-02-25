function datarec=mrinfo2datarec(varargin)
% MRINFO2DATAREC Convert a MR header to a BXH datarec structure
%
%    datarec = mrinfo2datarec(info);
%    datarec = mrinfo2datarec(info, type);
%    datarec = mrinfo2datarec(info, type, subtype);

% CVSId = '$Id: mrinfo2datarec.m,v 1.24 2005/02/03 16:58:39 michelich Exp $';
% CVSRevision = '$Revision: 1.24 $';
% CVSDate = '$Date: 2005/02/03 16:58:39 $';
% CVSRCSFile = '$RCSfile: mrinfo2datarec.m,v $';

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
  nargchk(nargin, 1, 3);

  datarec = [];
  
  info = varargin{1};
  if nargin > 1
    datarec.ATTRS.type.VALUE = varargin{2};
  end
  if nargin > 2
    datarec.ATTRS.subtype.VALUE = varargin{3};
  end

  if strcmp(info.outputelemtype, 'double')
    info.outputelemtype = 'float64';
  end
  if strcmp(info.outputelemtype, 'single')
    info.outputelemtype = 'float32';
  end
  datarec.elementtype{1}.VALUE = info.outputelemtype;

  if info.byteorder == 'b'
    datarec.byteorder{1}.VALUE = 'msbfirst';
  elseif info.byteorder == 'l'
    datarec.byteorder{1}.VALUE = 'lsbfirst';
  else
    emsg='Bad byteorder!'; error(emsg);
  end

  for dimnum=1:length(info.dimensions)
    infodim = info.dimensions(dimnum);
    dim = [];
    dim.ATTRS.type.VALUE = infodim.type;
    if ~isempty(infodim.units) & ischar(infodim.units)
      dim.units{1}.VALUE = infodim.units;
    end
    dim.size{1}.VALUE = infodim.size;
    if isfield(infodim, 'outputselect') & ...
          ~isempty(infodim.outputselect) & ~isnan(infodim.outputselect)
      dim.ATTRS.outputselect.VALUE = infodim.outputselect - 1; % make indexing start at 0
    end
    if ~isempty(infodim.origin) & ~isnan(infodim.origin)
      dim.origin{1}.VALUE = infodim.origin;
    end
    if ~isempty(infodim.gap) & ~isnan(infodim.gap)
      dim.gap{1}.VALUE = infodim.gap;
    end
    if ~isempty(infodim.spacing) & ~isnan(infodim.spacing)
      dim.spacing{1}.VALUE = infodim.spacing;
    end
    if isfield(infodim, 'datapoints') & ~isnan(infodim.datapoints{1})
      allscalar = 1;
      for i=1:length(infodim.datapoints)
        point = infodim.datapoints{i};
        if ~isnumeric(point) | length(point) > 1
          allscalar = 0;
          break
        end
      end
      for i=1:length(infodim.datapoints)
        if allscalar
          dim.datapoints{1}.VALUE(i) = infodim.datapoints{i};
        else
          dim.datapoints{1}.value{i}.VALUE = infodim.datapoints{i};
        end
      end
    end
    if ~isempty(infodim.direction) & ~isnan(infodim.direction(1))
      dim.direction{1}.VALUE = infodim.direction;
      if strcmp(infodim.type, 'z')
        orient = '';
        [maxval, index] = max(abs(infodim.direction));
        if abs(maxval) ~= 1
          orient = [orient 'oblique '];
        end
        switch index
         case 1, orient = [orient 'sagittal'];
         case 2, orient = [orient 'coronal'];
         case 3, orient = [orient 'axial'];
        end
        datarec.COMMENTS = [];
        datarec.COMMENTS(1).VALUE = ['AUTOGEN: Orientation is ' orient ' '];
        datarec.COMMENTS(1).CHILDRANK = -1;
      end
    end
    if ~isempty(infodim.directionprecision) & ~isnan(infodim.directionprecision)
      dim.direction{1}.ATTRS.precision.VALUE = infodim.directionprecision;
    end
    datarec.dimension{dimnum} = dim;
  end
  
  if isfield(info, 'frags')
    for fragnum=1:length(info.frags)
      infofrag = info.frags(fragnum);
      datarec.filename{fragnum}.VALUE = infofrag.filename;
      if isfinite(infofrag.fileoffset) & infofrag.fileoffset >= 0
        datarec.fileoffset{fragnum}.VALUE = infofrag.fileoffset;
      end
      if isfinite(infofrag.fragsize) & infofrag.fragsize >= 0
        datarec.filerecordsize{fragnum}.VALUE = infofrag.fragsize;
      end
    end
  end
  
  BXHNS = 'http://www.biac.duke.edu/bxh';
  queue = { 'datarec' };
  while length(queue) > 0
    expr = queue{1};
    queue(1) = [];
    if (length(expr) >= length('.ATTRS') | isempty(findstr(expr, '.ATTRS')))...
          & eval(['isstruct(' expr ')'])
      eval([expr '.NAMESPACE = ''' BXHNS ''';']);
      newexprs = strcat([expr '.'], eval(['fieldnames(' expr ')']));
      for exprnum=1:length(newexprs)
        newexpr = newexprs{exprnum};
        if eval(['iscell(' newexpr ')'])
          numcells = eval(['length(' newexpr ');']);
          for cellnum=1:numcells
            queue{length(queue)+1} = [newexpr '{' num2str(cellnum) '}'];
          end
        end
      end
    end
  end
  
  if isfield(info, 'unparsed')
    names = fieldnames(info.unparsed);
    for namenum = 1:length(names)
      name = names{namenum};
      eval(['datarec.' name ' = info.unparsed.' name ';']);
      for valnum = 1:length(eval(['datarec.' name]))
        eval(['datarec.' name '{valnum}.ATTRS.validation.VALUE = ''This value was not parsed during conversion and may be inaccurate.'';']);
      end
    end
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
% $Log: mrinfo2datarec.m,v $
% Revision 1.24  2005/02/03 16:58:39  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.23  2004/07/30 19:43:55  gadde
% Fix potential bug
%
% Revision 1.22  2004/05/06 14:47:19  gadde
% Replace all uses of strfind with findstr (strfind doesn't exist before
% Matlab 6.1).
%
% Revision 1.21  2004/01/22 20:14:46  gadde
% Encourage 'float64' instead of 'double', but support those type
% names that aren't Matlab types.
%
% Revision 1.20  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.19  2003/10/22 15:31:36  gadde
% Add support for outputselect attribute
%
% Revision 1.18  2003/10/13 20:29:52  gadde
% Add VALUE (oops).
%
% Revision 1.17  2003/07/24 19:22:18  gadde
% Allow for NaN in fileoffset and fragsize.
%
% Revision 1.16  2003/07/03 20:22:37  gadde
% Use more consistent elemtype description in info by adding
% rawelemtype (input) and outputelemtype (output).
%
% Revision 1.15  2003/06/25 20:59:53  gadde
% add precision attribute to direction vectors (missing means infinite)
%
% Revision 1.14  2003/06/06 14:19:46  gadde
% Make datapoints a cell array (to allow for encapsulated "value" elements).
%
% Revision 1.13  2003/05/16 21:00:32  gadde
% Even though it doesn't matter, change all last 'desc's to 'info's
%
% Revision 1.12  2003/04/18 16:34:42  gadde
% New COMMENT structure.
%
% Revision 1.11  2003/04/16 15:07:44  gadde
% Use new "CHILDRANK" field to do what "ORDER" did before.
% Now XML structures are much more robust when modified
% (e.g. adding/deleting elements).
%
% Revision 1.10  2003/04/01 21:15:34  gadde
% Allow [] or NaN to represent unspecified values.
%
% Revision 1.9  2003/03/31 20:50:28  gadde
% Finish desc->info changes.
% Put orientation into comment rather than element.
%
% Revision 1.8  2003/01/14 21:05:27  gadde
% Oops, dynamic field names don't work in 6.1.
%
% Revision 1.7  2003/01/14 16:45:01  gadde
% Replace tabs with spaces.
%
% Revision 1.6  2003/01/14 16:44:23  gadde
% Fixed spelling mistake and added support for unparsed fields in datarec.
%
% Revision 1.5  2003/01/14 16:16:21  gadde
% Replace variables names hdr* with desc*.
%
% Revision 1.4  2003/01/13 21:59:41  gadde
% Allow structs without frags.
%
% Revision 1.3  2003/01/10 15:32:01  gadde
% Changed logical operators from short-circuit to element-wise
%
% Revision 1.2  2003/01/06 20:59:40  gadde
% Bring back try/catch.
%
% Revision 1.1  2003/01/06 20:57:38  gadde
% First commit
%
