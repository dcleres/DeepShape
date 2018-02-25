function [values,code] = xpathquery(xml,query_string)
%XPATHQUERY - Query an XML structure for a field using XPath
%
% [values,code] = xpathquery(xml,query_string);
%
% xml          - an XML structure (as read by READXML) or an XML filename.
% query_string - the XPath query string.
% values       - the VALUE if a single node matches, or a cell array of
%                VALUEs if multiple nodes match.  If no nodes matched,
%                values is [].
% code         - Numeric result code indicating: 
%     (code >  0) - a valid value (code is the number of matching nodes)
%     (code =  0) - field exists but has empty VALUE
%     (code = -1) - field exists but has no VALUE
%     (code = -2) - field doesn't exist
% 
% Examples:
% % Use XML filename
% [value,code]=xpathquery('run005_02.bxh','/bxh/datarec/dimension/units');
% [value,code]=xpathquery('run005_02.bxh','/bxh/datarec/dimension[3]/units')
% [value,code]=xpathquery('run005_02.bxh','/bxh/datarec/@type')
%
% % Use parsed XML structure
% bxh = readxml('run005_02.bxh');
% [value,code]=xpathquery(bxh,'/bxh/subject/sex');
%
% % Use parsed XML structure from readmr.
% mrstruct = readmr('run005_02.bxh');
% [value,code]=xpathquery(mrstruct.info.hdr,'/bxh/acquisitiondata/scantime')
%
% See Also: READMR, READXML

% CVSId = '$Id: xpathquery.m,v 1.7 2005/02/03 16:58:36 michelich Exp $';
% CVSRevision = '$Revision: 1.7 $';
% CVSDate = '$Date: 2005/02/03 16:58:36 $';
% CVSRCSFile = '$RCSfile: xpathquery.m,v $';

% Additional examples for testing:
%   [value,code]=xpathquery(bxh,'/bxh/subject/sex')
%   [value,code]=xpathquery(bxh,'/bxh/acquisitiondata/scantime')
%   [value,code]=xpathquery(bxh,'/bxh/datarec/filename')
%   [value,code]=xpathquery(bxh,'/bxh/datarec/dimension/size')
%   [value,code]=xpathquery(bxh,'/bxh/datarec/dimension/origin')
%   [value,code]=xpathquery(bxh,'/bxh/datarec/dimension/gap')
%
%   [value,code]=xpathquery('run005_02.bxh','/bxh/subject/weight')
%   [value,code]=xpathquery('run005_02.bxh','/bxh/datarec/filename')
%   [value,code]=xpathquery('run005_02.bxh','/bxh/datarec/dimension/units')
%   [value,code]=xpathquery('run005_02.bxh','/bxh/datarec/dimension/size')
%
%   [value,code]=xpathquery('run005_02.bxh','/bxh/datarec/@type')
%   [value,code]=xpathquery('run005_02.bxh','/bxh/@version')
%
%   [value,code]=xpathquery('run005_02.bxh','/bxh/datarec/dimension[0]/units')
%   [value,code]=xpathquery('run005_02.bxh','/bxh/datarec/dimension[3]/units')
%   [value,code]=xpathquery('run005_02.bxh','/bxh/datarec/filename[36]')

% ________________________________________________________________
% initialization
debug_flag=0; % if (debug_flag==1), print out the whole checking history
              % if (debug_flag==0), only output [value, code]
code=0;
values=[];

% ________________________________________________________________
% Check input arguments.
error(nargchk(2,2,nargin));
if ~(ischar(xml) | isstruct(xml))
  error('xml must be a xmlfilename or a parsed xml structure');
end
% Check format of XPath string
if ~ischar(query_string) | size(query_string,1) ~= 1 | size(query_string,2) < 1
  error('Invalid XPath query.  query_string must be a 1 x n string!');
end
if query_string(1) ~= '/'
  error('Invalid XPath query.  query_string must begin with /');
end
if query_string(end) == '/'
  error('Invalid XPath query.  query_string ends with /');
end

% ________________________________________________________________
% read in xml info

if ischar(xml) % pass in a filename instead
  xmlfile = xml;
  try
    xml=readxml(xmlfile);
  catch
    error(sprintf('Unable to parse XML file %s',xmlfile));
  end
  clear xmlfile
end

% ________________________________________________________________
% break down the query_string into path_components
% path_components - an array of chopped components from the query_string; string

ii = find(query_string == '/');
path_components = cell(1,length(ii));  % Allocate cell array for nodes.
path_components_index = length(path_components);  % Number of nodes.
for n = 1:(path_components_index-1)
  path_components{n} = query_string((ii(n)+1):(ii(n+1)-1));
end
path_components{path_components_index} = ...
  query_string((ii(path_components_index)+1):end);

% ________________________________________________________________
% check if the user requests attribute, namespace, childrank etc.
% request = 0, request VALUE
%         = 1, request ATTRS
%         = ... add on if there is a need, i.e. NAMESPACE request etc.

request=0;
if path_components{end}(1) == '@'
  path_components{end+1} = path_components{end}(2:end);
  path_components{end-1} = 'ATTRS';
  request = 1;
end

% ________________________________________________________________
% modify the instance from xml format to MATLAB format
% i.e.
%   /bxh/datarec/dimension[1]/units --> /bxh/datarec/dimension{1}/units
%
%   rule changed that the index starts with 1 for both format
%   /bxh/datarec/dimension[1]/units --> /bxh/datarec/dimension{1}/units
%   .... change made on 6/20/2003 by Michael Wu

for j = 1:length(path_components)
  if find(path_components{j} == '[') > 0
    r_bracket = find(path_components{j} == '[');
    xml_format = path_components{j}(r_bracket:end);
    MatLab_format=sprintf('{%d}',...
      str2num(path_components{j}(r_bracket+1:end-1)));
    path_components{j} = strrep(path_components{j},...
      xml_format,MatLab_format);
  end % </end if find(path...>
end % </end for j = 1:length ...>

%________________________________________________________________
% create queue cell array and exhaustively process each cell array element
% check if the xml header is a structure

%--------------------------------------------------------------
% initialize the loop

path_root='xml';
values = {};
queue = { { path_root, path_components } };

if ~isstruct(eval(path_root))
  error('xmlhdr is not a valid parsed XML file or is not a structure.'); 
end

%--------------------------------------------------------------
% main while loop to process the queue exhaustively

while length(queue) > 0
  
  % shove the first cell element for processing
  clear parent path_components;
  [parent, path_components] = deal(queue{1}{:}); % all strings
  
  % shorten the queue cell array by ripping off the 1st elemt in queue
  queue(1) = [];
  
  % check if the end of the query node is reached  
  if isempty(path_components)
    [values, code] = end_point_check(xml,parent,values,code,request,debug_flag);
    
    % otherwise extend the queue  
  else
    
    % a particular instance is specified, no branching
    if find(path_components{1}=='}') > 0
      [temp_component,remainder]=strtok(path_components{1},'{');
      instance_index=str2num(remainder(2:end-1));
      if isfield(eval(parent),temp_component)
        if instance_index > length(eval(sprintf('%s.%s',parent,...
            temp_component)))
          if (debug_flag==1)
            disp(sprintf(...
              'The index %d of %s exceeds its possible dimension',...
              instance_index,temp_component));
          end
          values{end+1}=[];
          code=-2;
        else
          queue{end+1} = { sprintf('%s.%s',parent,...
              path_components{1}), {path_components{2:end}} };
        end % </ end if length(eval(sp ... >
      else % the immediate child path_compnent ~isfield of the parent
        % Set code, return
        if (debug_flag==1)
          disp(sprintf('%s is not a field of %s or does not exist at all.',...
            path_components{1},parent));
        end
        values{end+1}=[];
        code = -2;
        return;          
      end % </ end if isfield(eval(parent),temp_component) >
      % else a particular instance is not specified, branch 
    else
      % check if the immediate path_component isfield of the parent
      if isfield(eval(parent),path_components{1})         
        % construct braching queues if instance is not specified
        if iscell(eval(sprintf('%s.%s',parent,path_components{1})))
          for k=1:length(eval(sprintf('%s.%s',parent,path_components{1})))
            queue{end+1} = { sprintf('%s.%s{%d}',parent,...
                path_components{1},k), {path_components{2:end}} };
          end % </end for k>
        elseif isstruct(eval(sprintf('%s.%s',parent,path_components{1})))
          queue{end+1} = { sprintf('%s.%s',parent,...
              path_components{1}), {path_components{2:end}} };
        end % </end if iscell ... >
        
      else % the immediate child path_compnent ~isfield of the parent
        % Set code, return
        if (debug_flag==1)
          disp(sprintf('%s is not a field of %s or does not exist at all.',...
            path_components{1},parent));
        end
        values{end+1}=[];
        code = -2;
        return;
      end % </ end if isfield(eval(parent ... >
    end % <end if find(path_components{1} ... >
  end % </end isempty(path_components)>        
end % </end while loop>

% If it is a single value, take it out of the cell.
if length(values) == 1, values = values{1}; end

% ________________________________________________________________
% </end of xpathquery>


%--------------------------------------------------------------
% <check_final_node>
% subfunction to retrieve VALUES, ATTRS, etc. ...
function [values,code]=end_point_check(xml,path,...
  values,code,request,debug_flag)

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if isempty(eval(path))
  if (debug_flag==1)
    disp(sprintf('Field %s exists but is empty.',path));
  end
  values{end+1}=[]; code=0;
end

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if (debug_flag==1)
  if iscell(eval(path)) %if last node is cell
    if (length(eval(path))==1) % if single cell
      disp(sprintf('%s exists and is a single cell:',path));
    elseif (length(eval(stub)) > 1) % if multiple cells
      disp(sprintf('%s exists and is multiple cell arrays:',path));
    end
  end % </end of iscell>
end % </end of if debug_flag> 		

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if isstruct(eval(path)) % if last node is struct
  
  % obtain the child field names
  if (debug_flag==1) 
    disp(sprintf('Field %s exists and has the follwing sub field names:',path));
    fieldnames(eval(path)) % for debugging purpose
  end
  
  switch request
    case 0 % obtain VALUE
      if isfield(eval(path),'VALUE')
        if isempty(eval(sprintf('%s.VALUE',path)))
          if (debug_flag==1)
            disp(sprintf('Field %s exists but has an empty VALUE:',path));
          end
          values{end+1}=[];
          code=0;
        else % retrieve the value;
          values{end+1}=eval(sprintf('%s.VALUE',path));
          code=code+1;
        end
      elseif ~isfield(eval(path),'VALUE')
        if (debug_flag==1)
          disp(sprintf('Field %s exists but does not have a VALUE:',path));
        end
        values{end+1}=[];
        code=-1;
      end
      
    case 1 % obtain ATTRIBUTES
      if isfield(eval(path),'VALUE')
        if isempty(eval(sprintf('%s.VALUE',path)))
          values{end+1} = [];
          code = 0;
        else
          values{end+1} = eval(sprintf('%s.VALUE',path));
          code=code+1;
        end
      elseif ~isfield(eval(path),'VALUE')
        if (debug_flag==1)
          disp(sprintf('Path %s exists but does not have an ATTRS value:',path));
        end
        values{end+1}=[];
        code=-2;
      end
      
    otherwise
      
  end % </end switch request>
  
  %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
else % or the last node merely contains value(s)
  % retrieve the value(s)
  values{end+1}=eval(path);
end % end if for the isstruct/iscell 
%--------------------------------------------------------------
% </check_final_node>

% Modification History:
%
% $Log: xpathquery.m,v $
% Revision 1.7  2005/02/03 16:58:36  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.6  2003/11/04 01:40:41  michelich
% Take single value out of cell.
%
% Revision 1.5  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.4  2003/07/18 17:00:45  michelich
% Pass debug_flag to end_point_check.
%
% Revision 1.3  2003/07/18 16:57:36  michelich
% Changed DEBUG to debug_flag since debug is a help m-file in MATLAB already.
%
% Revision 1.2  2003/07/17 19:01:04  michelich
% Use code == -2 for missing attribute.
% Don't display messages unless DEBUG is on & only initialize DEBUG once.
% Comment updates & clear using single function call.
%
% Revision 1.1  2003/07/17 18:31:03  michelich
% Initial CVS Import.  Code written by Michael Wu.
%
% Pre CVS History Entries:
% Written by Michael Wu (first on 06/10/2003)
% Thanks to Chuck and Syam for their ideas and helps
% - instance request functionality added 6/20/2003
% - attribute request functionality added 6/20/2003
% - change the branching method to queue arrays 6/20/2003
% - enabled parallel branching (assume parallel query trees) 6/17/2003
% - changed the check last node into a subfunction 6/17/2003
