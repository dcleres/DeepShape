function [minA,maxA]=minmax(A)
%MINMAX Return min and max of noncomplex, nonsparse array of doubles.
%
%   [min max]=minmax(A);
%   [limits]=minmax(A);
%
%   A is a noncomplex, nonsparse array of doubles.
%   min is the global minimum of A.
%   max is the global maximum of A.
%   limits is a row vector containing [min max].
%
%   Notes:
%   If A is empty, [] is returned.
%   NaN's are ignored.
%   If A is all NaN's, [NaN NaN] is returned.

% CVS ID and authorship of this code
% CVSId = '$Id: minmax.m,v 1.6 2005/02/03 16:58:34 michelich Exp $';
% CVSRevision = '$Revision: 1.6 $';
% CVSDate = '$Date: 2005/02/03 16:58:34 $';
% CVSRCSFile = '$RCSfile: minmax.m,v $';

% Implemented as a MEX file also (faster)

% Warn user to build MEX the first time it is used.
persistent haveWarned
if isempty(haveWarned)
  warning('Using m-file version of minmax().  Compile minmax.c for better performance!');
  haveWarned = 1;
end

% Check arguments 
error(nargchk(1,1,nargin));
if nargout > 2, error('Too many output arguments.'); end
% Make these requirements so that it is equivalent to the MEX implementation
if ~isreal(A) | issparse(A) | ~isa(A,'double')
  error('MINMAX requires that A be an array of noncomplex, nonsparse double.');
end

% Calculate min and max
minA=min(A(:));
maxA=max(A(:));

% If 0 or 1 output arguments, return a vector
if nargout ~= 2
  minA=[minA,maxA];
end

% Modification History:
%
% $Log: minmax.m,v $
% Revision 1.6  2005/02/03 16:58:34  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.5  2004/05/06 15:15:27  gadde
% Remove all dependencies on ispc and nargoutchk (for compatibility
% with Matlab 5.3).
%
% Revision 1.4  2003/10/22 15:54:36  gadde
% Make some CVS info accessible through variables
%
% Revision 1.3  2003/06/16 18:28:14  michelich
% Only issue MEX file warning once.
%
% Revision 1.2  2002/09/09 19:45:32  michelich
% Implemented as m-file in case MEX file not complied for current platform.
%
% Revision 1.1  2002/08/27 22:24:16  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Francis Favorini,  1998/10/13.
% Charles Michelich, 2001/01/23. Changed filename to lowercase.
