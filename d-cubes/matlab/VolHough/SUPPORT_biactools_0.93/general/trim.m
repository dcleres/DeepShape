function s1=trim(s)
%TRIM   Remove leading and trailing blanks.
%   TRIM(S) removes leading and trailing blanks from string S and returns result.

% CVS ID and authorship of this code
% CVSId = '$Id: trim.m,v 1.4 2005/02/03 20:17:46 michelich Exp $';
% CVSRevision = '$Revision: 1.4 $';
% CVSDate = '$Date: 2005/02/03 20:17:46 $';
% CVSRCSFile = '$RCSfile: trim.m,v $';

if ~isempty(s) & ~ischar(s)
    warning('Input must be a string.')
end

if isempty(s)
    s1 = s;
else
  % remove leading and trailing blanks
  [r,c] = find(s ~= ' ' & s ~= 0);
  s1 = s(:,min(c):max(c));
  if isempty(s1) 
    s1 = '';
  end
end

% Modification History:
%
% $Log: trim.m,v $
% Revision 1.4  2005/02/03 20:17:46  michelich
% M-Lint: Replace deprecated isstr with ischar.
%
% Revision 1.3  2005/02/03 16:58:36  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2002/08/27 22:24:20  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Francis Favorini, 1997/10/16.  Based on MATLAB deblank.m
