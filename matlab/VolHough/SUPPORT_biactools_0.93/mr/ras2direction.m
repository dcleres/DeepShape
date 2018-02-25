function directionVecs = ras2direction(rasflag)
%RAS2DIRECTION Create direction vectors from specified RAS orientation
%
%  Determine direction vectors for a specifed rasflag assuming that images
%  are NOT oblique.
%
%  directionVecs = ras2direction(rasflag); 
%
%  Input variables:
%  rasflag is a three character string indicating the current orientation
%    Three character indicating direction of increasing values
%    in each of three dimensions.
%     e.g. lpi ->  X: L to R, Y: A to P, Z: S to I (Standard Axial S to I)
%  directionVecs is a cell array of the direction vectors for x,y,z
%    corresponding to the specifed rasflag (Assumes images are NOT oblique)
%
% See Also: GETORIENTATION, REORIENT, READMR
%

% CVS ID and authorship of this code
% CVSId = '$Id: ras2direction.m,v 1.4 2005/02/03 16:58:41 michelich Exp $';
% CVSRevision = '$Revision: 1.4 $';
% CVSDate = '$Date: 2005/02/03 16:58:41 $';
% CVSRCSFile = '$RCSfile: ras2direction.m,v $';

% Check input arguments
error(nargchk(1,1,nargin));
if ~ischar(rasflag) | any(size(rasflag) ~= [1 3])
  error('rasflag must be a three character string!');
end

% Check that RAS flag is valid
tmpflag=rasflag;
tmpflag(find(tmpflag=='l'))='r';
tmpflag(find(tmpflag=='p'))='a';
tmpflag(find(tmpflag=='i'))='s';
if ~strcmp(sort(tmpflag),'ars'), error('rasflag is not a valid RAS flag!'); end

% Determine direction vectors
directionVecs = cell(1,3);
for n=1:3
  if rasflag(n) == 'r', directionVecs{n} = [1 0 0];
  elseif rasflag(n) == 'l', directionVecs{n} = [-1 0 0];
  elseif rasflag(n) == 'a', directionVecs{n} = [0 1 0];
  elseif rasflag(n) == 'p', directionVecs{n} = [0 -1 0];
  elseif rasflag(n) == 's', directionVecs{n} = [0 0 1];
  else directionVecs{n} = [0 0 -1]; % 'i'
  end
end

% Modification History:
%
% $Log: ras2direction.m,v $
% Revision 1.4  2005/02/03 16:58:41  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.3  2003/10/22 15:54:38  gadde
% Make some CVS info accessible through variables
%
% Revision 1.2  2003/06/30 16:54:30  michelich
% Updated for readmr name change.
%
% Revision 1.1  2003/06/12 21:33:13  michelich
% Original.
%
