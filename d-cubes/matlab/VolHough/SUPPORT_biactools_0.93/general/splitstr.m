function cStr=splitstr(str,delim)
%SPLITSTR Split string into a cell array of string.
%
%   cStr=splitstr(str);
%   cStr=splitstr(str,delim);
%
%   str is a string.
%   delim is a delimiter on which to break str.
%     delim is interpreted by sprintf, so you can use '\n', '\t', etc.
%     Default is '\n'.
%   cStr is the cell array of resulting strings, with delim removed.
%
%   Examples:
%   >>cStr=splitstr('one two three',' ')
%   cStr = 
%       'one'
%       'two'
%       'three'

% CVS ID and authorship of this code
% CVSId = '$Id: splitstr.m,v 1.3 2005/02/03 16:58:36 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:36 $';
% CVSRCSFile = '$RCSfile: splitstr.m,v $';

% Check args and supply defaults
error(nargchk(1,2,nargin));
if nargin<2, delim='\n'; end

cStr={};
j=1;
for i=[find(str==sprintf(delim)) length(str)+1]
  s=str(j:i-1);
  if isempty(s), s=''; end    % Get rid of "Empty matrix: 1-by-0"
  cStr=[cStr; {s}];
  j=i+1;
end

% Modification History:
%
% $Log: splitstr.m,v $
% Revision 1.3  2005/02/03 16:58:36  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:36  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2002/08/27 22:24:19  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2001/01/23. Changed function name to lowercase.
% Francis Favorini,  1999/10/13.

