function varargout=cindex(a,varargin)
%CINDEX Return values of cell array at subscripts.
%       b=CINDEX(a,sub1,sub2,...)
%       Useful when a is a function return value or in brackets form.
%       b is set to a(sub1,sub2,...).
%
%       See also INDEX.

% CVS ID and authorship of this code
% CVSId = '$Id: cindex.m,v 1.3 2005/02/03 16:58:32 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:32 $';
% CVSRCSFile = '$RCSfile: cindex.m,v $';

varargout=a(varargin{:});

% Modification History:
%
% $Log: cindex.m,v $
% Revision 1.3  2005/02/03 16:58:32  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:34  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2002/08/27 22:24:14  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Francis Favorini, 1998/10/13. Mirrors INDEX.
