function spec=name2spec(name)
%NAME2SPEC Convert MR series name to specifier.
%
%   spec=name2spec(name);
%
%   Example:
%   >>name2spec('\\broca\data2\study\raw\run01\v0001.img')
%   ans =
%   \\broca\data2\study\raw\run01\v*.img
%
%   >>name2spec('\\server\share\study\data\anat\I.001')
%   ans =
%   \\server\share\study\data\anat\I.*

% CVS ID and authorship of this code
% CVSId = '$Id: name2spec.m,v 1.4 2005/02/03 16:58:40 michelich Exp $';
% CVSRevision = '$Revision: 1.4 $';
% CVSDate = '$Date: 2005/02/03 16:58:40 $';
% CVSRCSFile = '$RCSfile: name2spec.m,v $';

% Find first non-numeric character (right to left)
for c = length(name):-1:1
  if name(c)<'0' | name(c)>'9', break; end
end
if c ~= length(name)
  % Found numeric characters, replace with *
  spec = strcat(name(1:c),'*');
else
  % All non-numeric character, strip extension and try again
  dot=findstr('.',name);
  if isempty(dot)
    % No extension, just return original
    spec=name;
  else
    dot=dot(end);
    % Find first non-numeric character (right to left)
    for c=dot-1:-1:1
      if name(c)<'0' | name(c)>'9', break; end
    end
    if c==dot-1
      % All non-numeric characters, just return name
      spec=name;
    else
      % Replace numeric characters with *
      spec=strcat(name(1:c),'*',name(dot:end));
    end
  end
end

% Modification History:
%
% $Log: name2spec.m,v $
% Revision 1.4  2005/02/03 16:58:40  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.3  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.2  2003/06/29 21:00:54  michelich
% Support striping numeric extensions (i.e. Signa5 I.* images).
%
% Revision 1.1  2002/08/27 22:24:22  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Francis Favorini, 1998/11/23.