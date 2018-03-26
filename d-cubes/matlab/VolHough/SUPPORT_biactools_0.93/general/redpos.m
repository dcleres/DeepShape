function [cmap]=redpos(n)
%REDPOS Generate colormap of dark red fading to bright yellow.
%    REDPOS(M) returns an M-by-3 matrix containing the colormap.
%    REDPOS, by itself, is the same length as the current colormap.

% CVS ID and authorship of this code
% CVSId = '$Id: redpos.m,v 1.3 2005/02/03 16:58:35 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:35 $';
% CVSRCSFile = '$RCSfile: redpos.m,v $';

if nargin<1, n=length(colormap); end
n1=round(n/3);
n2=n-n1;
r=linspace(0.5,1,n1+1);
r=[r(1:end-1) ones(1,n2)];
g=[zeros(1,n1) linspace(0,1,n2)];
b=zeros(1,n);
cmap=[r; g; b]';

% Modification History:
%
% $Log: redpos.m,v $
% Revision 1.3  2005/02/03 16:58:35  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:36  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2002/08/27 22:24:18  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Francis Favorini, 1998/06/16.

