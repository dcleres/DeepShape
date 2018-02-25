function vi=scale3(v,xs,ys,zs)
%SCALE3 Scale 3-D array in X, Y, and Z.
%
%   VI=SCALE3(V,XS,YS,ZS);
%
%   Scale 3-D array V using trilinear interpolation.
%   XS, YS, and ZS are the scale factors in X, Y, and Z.
%
%   X is the first dimension, Y is the second, and Z is the third.
%   In order to preserve the original data points when using
%   integer scale factors, the reciprocal of the scale factor
%   is used to step from 1 to the corresponding dimension of V.
%   Then the final X, Y, and Z positions are replicated to fill
%   out the scaled array.  These vectors are then used to
%   interpolate.
%   size(VI) will be [size(V,1)*XS size(V,2)*YS size(V,3)*ZS].
%
%   See also XMR, TRILINEAR, INTERP3.

% CVS ID and authorship of this code
% CVSId = '$Id: scale3.m,v 1.8 2005/02/03 16:58:36 michelich Exp $';
% CVSRevision = '$Revision: 1.8 $';
% CVSDate = '$Date: 2005/02/03 16:58:36 $';
% CVSRCSFile = '$RCSfile: scale3.m,v $';

error(nargchk(4,4,nargin))
if ~any(isint([xs,ys,zs]))
  error('Scale factors must be integers!  Use trilinear to downsample image.');
end

% Set up grid for interpolation
% Replicate last X, Y, and Z positions to avoid out of range coords
x=size(v,1);
y=size(v,2);
z=size(v,3);
xi=[1:1/xs:x x*ones(1,xs-1)];
yi=[1:1/ys:y y*ones(1,ys-1)];
zi=[1:1/zs:z z*ones(1,zs-1)];
% Interpolate
vi=trilinear(v,xi,yi,zi);

% Modification History:
%
% $Log: scale3.m,v $
% Revision 1.8  2005/02/03 16:58:36  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.7  2004/11/01 04:30:08  michelich
% Backout untested revision 1.5 (Option to scale without shifting data.)
%
% Revision 1.6  2003/10/22 15:54:36  gadde
% Make some CVS info accessible through variables
%
% Revision 1.5  2003/05/08 17:20:39  michelich
% Added option to scale without shifting data.
%
% Revision 1.4  2002/11/12 16:05:36  michelich
% Fixed integer scale factor check & updated error message.
%
% Revision 1.3  2002/09/11 00:22:58  michelich
% Corrected syntax of isint function call
%
% Revision 1.2  2002/09/10 21:26:31  michelich
% Added check that scale factors are integers (as required by code to generate xi, yi, zi).
%
% Revision 1.1  2002/08/27 22:24:19  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2001/01/23. Changed function name to lowercase.
% Francis Favorini,  1998/11/19.

