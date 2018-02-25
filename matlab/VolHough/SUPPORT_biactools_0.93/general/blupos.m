function [cmap]=blupos(n)
%BLUPOS Generate colormap of dark blue fading to bright cyan.
%    BLUPOS(M) returns an M-by-3 matrix containing the colormap.
%    BLUPOS, by itself, is the same length as the current colormap.

% CVS ID and authorship of this code
% CVSId = '$Id: blupos.m,v 1.3 2005/02/03 16:58:32 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:32 $';
% CVSRCSFile = '$RCSfile: blupos.m,v $';

if nargin<1, n=length(colormap); end
cmap=flipud(bluneg(n));

% Modification History:
%
% $Log: blupos.m,v $
% Revision 1.3  2005/02/03 16:58:32  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:34  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2002/08/27 22:24:13  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Francis Favorini, 1998/06/16.
