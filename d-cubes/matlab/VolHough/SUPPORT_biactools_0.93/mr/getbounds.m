function corners=getbounds(srs)
%GETBOUNDS - Find the bounding box of an image volume
%
%  Return the corners of the bounding box that contains the specified image
%  volume.
%
%  corners=getbounds(srs)
%
%    srs is image volume (as read by READMR) to find boundary
%    corners is is a 2 x 3 matrix where is the first row is the starting
%      corner and the second row is the ending corner in RAS dimension
%      order.  The corners are the edge of the voxel.  If no outputs are
%      requested, the bounding box is displayed in a nice format.
%
% See Also: READMR

% CVS ID and authorship of this code
% CVSId = '$Id: getbounds.m,v 1.10 2005/02/03 16:58:39 michelich Exp $';
% CVSRevision = '$Revision: 1.10 $';
% CVSDate = '$Date: 2005/02/03 16:58:39 $';
% CVSRCSFile = '$RCSfile: getbounds.m,v $';

error(nargchk(1,1,nargin));

% Check that input has necessary fields
if ~isstruct(srs) | ~isfield(srs,'info') | ...
    ~isfield(srs.info,'dimensions') | ...
    ~isfield(srs.info.dimensions,'direction') | ...
    ~isfield(srs.info.dimensions,'gap') | ...
    ~isfield(srs.info.dimensions,'origin') | ...
    ~isfield(srs.info.dimensions,'spacing') | ...
    ~isfield(srs.info.dimensions,'size')
  emsg='Input does not have necessary information to compare spatial locations'; error(emsg);
end

% Must have three dimensions ordered 'x','y','z'
if length(srs.info.dimensions) < 3
  emsg='srs must have at least three dimensions'; error(emsg);
end
if ~isequal({srs.info.dimensions(1:3).type},{'x','y','z'})
  emsg='The first three dimensions of srs must be x,y,z'; error(emsg);
end
  
% Reshape directions to have one row for each dimension.
directions=reshape([srs.info.dimensions(1:3).direction],3,3)';

% Get tranformation from current orientation to RAS orientation
% NOTE: All inputs have the same orientation since their direction vectors
%       are the same.
dim2ras=transformras(getorientation(srs),'ras');

% --- Get starting and ending points of bounding box ---
% Extract parameters
srsOrigin=[srs.info.dimensions(1:3).origin];
srsSpacing=[srs.info.dimensions(1:3).spacing];
srsSize=[srs.info.dimensions(1:3).size];

% Move back 1/2 voxel to the starting corner of the bounding box
startPt = srsOrigin(dim2ras) - (srsSpacing./2)*directions;

% Move forward to the ending corner of the bounding box in X direction.
endXPt = startPt + (srsSpacing.*srsSize.*[1 0 0])*directions;
% Move forward to the ending corner of the bounding box in Y direction.
endYPt = startPt + (srsSpacing.*srsSize.*[0 1 0])*directions;
% Move forward to the ending corner of the bounding box in Z direction.
endZPt = startPt + (srsSpacing.*srsSize.*[0 0 1])*directions;

% Move forward to the ending corner of the bounding box in all directions.
endPt = startPt + (srsSpacing.*srsSize)*directions;

%% end of box in X direction
%delta =[srsSpacing(1)*srsSize(1) 0 0] ;
%startPt + delta*directions
%% end of box in Y direction
%delta =[0 srsSpacing(2)*srsSize(2) 0] ;
%startPt + delta*directions
%% end of box in Z direction
%delta =[0 0 srsSpacing(3)*srsSize(3)] ;
%startPt + delta*directions

% Put results into a matrix
corners=cat(1,startPt,endPt);

% Pretty print bounding box if user does not request any outputs
if nargout == 0
  stdRAS=['RAS';'LPI']';
  startPtRAS=stdRAS((startPt<0).*3+[1:3]);
  endXPtRAS=stdRAS((endXPt<0).*3+[1:3]);
  endYPtRAS=stdRAS((endYPt<0).*3+[1:3]);
  endZPtRAS=stdRAS((endZPt<0).*3+[1:3]);
  endPtRAS=stdRAS((endPt<0).*3+[1:3]);
  disp(sprintf('Start Corner = %s %g, %s %g, %s %g',startPtRAS(1),abs(startPt(1)),...
    startPtRAS(2),abs(startPt(2)),startPtRAS(3),abs(startPt(3))));
  disp(sprintf('End Corner   = %s %g, %s %g, %s %g',endPtRAS(1),abs(endPt(1)),...
    endPtRAS(2),abs(endPt(2)),endPtRAS(3),abs(endPt(3))));
  disp(sprintf('End X Corner = %s %g, %s %g, %s %g',endXPtRAS(1),abs(endXPt(1)),...
    endXPtRAS(2),abs(endXPt(2)),endXPtRAS(3),abs(endXPt(3))));
  disp(sprintf('End Y Corner = %s %g, %s %g, %s %g',endYPtRAS(1),abs(endYPt(1)),...
    endYPtRAS(2),abs(endYPt(2)),endYPtRAS(3),abs(endYPt(3))));
  disp(sprintf('End Z Corner = %s %g, %s %g, %s %g',endZPtRAS(1),abs(endZPt(1)),...
    endZPtRAS(2),abs(endZPt(2)),endZPtRAS(3),abs(endZPt(3))));
  distX = sqrt(sum((endXPt-startPt).^2));
  distY = sqrt(sum((endYPt-startPt).^2));
  distZ = sqrt(sum((endZPt-startPt).^2));
  disp(sprintf('Volume dimensions [X Y Z] = [ %g %g %g ]', distX, distY, distZ));
end

% Modification History:
%
% $Log: getbounds.m,v $
% Revision 1.10  2005/02/03 16:58:39  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.9  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.8  2003/10/20 17:48:56  michelich
% Update comments for new function name.
%
% Revision 1.7  2003/10/02 21:20:01  gadde
% Make output prettier.
%
% Revision 1.6  2003/10/02 15:30:58  gadde
% Add more display (consider adding to return value?)
%
% Revision 1.5  2003/09/24 22:10:08  gadde
% Fix bounding box logic.
%
% Revision 1.4  2003/09/24 20:02:36  gadde
% Fix corner calculation (matrix multiplication strikes back!)
%
% Revision 1.3  2003/06/30 16:54:30  michelich
% Updated for readmr name change.
%
% Revision 1.2  2003/05/09 22:56:48  michelich
% Corrected error message
%
% Revision 1.1  2003/05/09 22:47:01  michelich
% Initial version.
%
