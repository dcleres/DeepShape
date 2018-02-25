function [rasflag,obliqueflag,commonName]=getorientation(srs)
%GETORIENTATION Determine orientation of specified image volume.
%
%   [rasflag,obliqueflag,commonName]=getorientation(srs)
%
%   Input variables:
%   srs is the image volume(s) as read by READMR or just the info structure
%     from an image volume read by READMR.
%     Must be have at least 3 or more dimensions ordered x,y,z
%
%   Output variables:
%   rasflag is a three character string indicating the current orientation
%      Three character indicating direction of increasing values
%      in each of three dimensions.
%       e.g. lpi ->  X: R to L, Y: A to P, Z: S to I (Standard Axial S to I)
%   obliqueflag indicates if this is an oblique image (~=0 is oblique)
%   commonName is a string with the common name for the orientation
%
%  Note: If no outputs are specified, a message containing the rasflag and
%        commonName is displayed.
%
% See Also: READMR

% CVS ID and authorship of this code
% CVSId = '$Id: getorientation.m,v 1.13 2005/02/03 16:58:39 michelich Exp $';
% CVSRevision = '$Revision: 1.13 $';
% CVSDate = '$Date: 2005/02/03 16:58:39 $';
% CVSRCSFile = '$RCSfile: getorientation.m,v $';

% Check number of inputs and outputs
error(nargchk(1,1,nargin));
if nargout > 3, error('Too many output arguments'); end

if isfield(srs,'info')
  % Extract info field from series if is there
  info = srs.info;
else
  % Otherwise assume input is info field
  info = srs;
end

% Check for fields we will use 
if ~isfield(info,'dimensions') | ~isfield(info.dimensions,'type') ...
    | ~isfield(info.dimensions,'direction')
  emsg='Invalid srs: Does not have info.dimensions type and/or direction field!'; error(emsg);
end
% Must have three dimensions ordered 'x','y','z' (TODO: Does the order matter???)
if length(info.dimensions) < 3
  emsg='srs must have at least three dimensions'; error(emsg);
end
if ~isequal({info.dimensions(1:3).type},{'x','y','z'})
  emsg='The first three dimensions of srs must be x,y,z'; error(emsg);
end

% Get directions vectors
directions=reshape([info.dimensions(1:3).direction],3,3);
if any(any(isnan(directions)))
  emsg='One of the directions vectors is not defined!'; error(emsg);
end

% Find max axis
[maxvals,ii]=max(abs(directions));
if length(unique(ii)) ~= length(ii),
  emsg='There are repetitions in the max axes!  THERE IS A BUG IN THE CODE!'; error(emsg);
end

% Set oblique flag
if any(maxvals < 1), obliqueflag=1; else obliqueflag=0; end

% --- Calculate the RAS flag ---
% directionsOrder indicates the flag of the increasing and decreases
% First column is Pos, Second column is Neg
directionOrder=['ras';'lpi']';
% ii contains the order of the dimensions in the current data
% Determine increasing direction as maxvals < 0 => Neg
vals=directions([0 3 6]+ii);
%vals=[directions(1,ii(1)), directions(2,ii(2)), directions(3,ii(3))];
rasflag=directionOrder(ii + (vals<0).*3);

% Find common name for current orientaiton
commonNames = { ...
    'ra','Axial'; ...
    'rs','Coronal'; ...
    'as','Sagittal'; ...
    'ar','Axial - XY Swapped'; ...
    'sr','Coronal - XY Swapped'; ...
    'sa','Sagittal - XY Swapped'};
commonName=commonNames{find(strcmp(directionOrder(ii(1:2)),commonNames(:,1))),2};
if obliqueflag, commonName=[commonName,' - Oblique']; end

% Display orientation if no outputs requested.
if nargout==0,
  disp(sprintf('Orientation is "%s" (%s)',rasflag,commonName));
  clear rasflag  % Do not set ans.
end

% Modification History:
%
% $Log: getorientation.m,v $
% Revision 1.13  2005/02/03 16:58:39  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.12  2005/01/28 20:52:01  michelich
% Fix typo in description of RAS flag.
%
% Revision 1.11  2004/05/06 15:15:34  gadde
% Remove all dependencies on ispc and nargoutchk (for compatibility
% with Matlab 5.3).
%
% Revision 1.10  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.9  2003/07/31 03:44:43  michelich
% Allow just passing info field of mrinfo struct.
%
% Revision 1.8  2003/06/30 16:54:30  michelich
% Updated for readmr name change.
%
% Revision 1.7  2003/06/13 15:50:11  gadde
% Fix checking of direction vectors.
%
% Revision 1.6  2003/05/09 20:55:23  michelich
% Revert to old error handling.
%
% Revision 1.5  2003/05/09 19:34:52  michelich
% Handle unable to determine current orientation more gracefully.
%
% Revision 1.4  2003/04/10 23:20:35  michelich
% Display nice string if no outputs requested.
%
% Revision 1.3  2003/04/04 21:50:45  gadde
% Fixed rasflag.
%
% Revision 1.2  2003/04/04 21:14:17  gadde
% Little fix to get oblique correct.
%
% Revision 1.1  2003/04/04 21:05:14  michelich
% Initial version.
%
