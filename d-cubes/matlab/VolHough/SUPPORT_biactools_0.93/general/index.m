function b=index(a,varargin)
%INDEX  Return values of matrix at subscripts.
%       b=INDEX(a,sub1,sub2,...)
%       Useful when a is a function return value or in brackets form.
%       b is set to a(sub1,sub2,...).
%
%       See also CINDEX.

% CVS ID and authorship of this code
% CVSId = '$Id: index.m,v 1.3 2005/02/03 16:58:34 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:34 $';
% CVSRCSFile = '$RCSfile: index.m,v $';

b=a(varargin{:});

% Modification History:
%
% $Log: index.m,v $
% Revision 1.3  2005/02/03 16:58:34  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:36  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2002/08/27 22:24:16  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Francis Favorini, 1998/08/19.  Now uses varargin.
% Francis Favorini, 1996/10/18.
