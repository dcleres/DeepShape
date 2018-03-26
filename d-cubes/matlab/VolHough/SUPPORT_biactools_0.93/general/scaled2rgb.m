function rgb = scaled2rgb(a,cm,clim)
%SCALED2RGB Convert scaled image to RGB image.
%   SCALED2RGB converts the matrix X and corresponding
%   colormap CMAP to RGB (truecolor) format using the 
%   specified clipping limits (CLIM).
%
%   RGB = SCALED2RGB(X,CMAP,CLIM)
%
%      X is input image to convert  (any number of dimensions)
%      CMAP is the colormap (n x 3)
%      CLIM is the clipping limits for the scaling
%      RGB is an size(X)-by-3 uint8 truecolor array (2 element vector)
%
%      CMAP can be:
%      - A standard MATLAB colormap (doubles with values between 0 and 1)
%      - A uint8 truecolor colormap generated using uint8(round(CMAP*255))
%          If the same colormap will be used many times and the image to
%          convert is small, cacheing the uint8 version of the colormap
%          will increase performance.
%
%   See also IND2RGB, IND2GRAY, RGB2IND (in the Image Processing Toolbox).

% CVS ID and authorship of this code
% CVSId = '$Id: scaled2rgb.m,v 1.7 2005/02/03 16:58:36 michelich Exp $';
% CVSRevision = '$Revision: 1.7 $';
% CVSDate = '$Date: 2005/02/03 16:58:36 $';
% CVSRCSFile = '$RCSfile: scaled2rgb.m,v $';

% Implemented as a MEX file also (faster)

% Warn user to build MEX the first time it is used.
persistent haveWarned
if isempty(haveWarned)
  warning('Using m-file version of scaled2rgb().  Compile scaled2rgb.c for better performance!');
  haveWarned = 1;
end

% Check inputs
error(nargchk(3,3,nargin));
if ~isreal(cm) | issparse(cm) | (~isa(cm,'double') & ~isa(cm,'uint8')) | ...
  (size(cm,2) ~= 3) | ndims(cm) ~= 2
  error('Colormap must be a n x 3 colormap array of real, non-sparse, doubles or uint8s!');
end
if isa(cm,'double') & ((max(cm(:)) > 1) | (min(cm(:)) < 0))
  error('All colormap (class=double) entries must be between zero and one!');
end
if ~all(size(clim) ~= [1 2]) & ~all(size(clim) ~= [2 1])
  error('CLim must be a two element vector!');
end
if clim(1) >= clim(2)
  error('CLim(1) must be < CLim(2) !');
end

% Scale input image to the size of the colormap
% (Scale image to go from 1 to size of the colormap)

% Standard MATLAB scaled CDataMapping technique:
% From MATLAB Help (Graphics: Axes Properties: Axes Color Limits - The CLim Property)
%   colormap_index = fix((CData-cmin)/(cmax-cmin)*cm_length)+1
%     where CLim = [cmin cmax]
%           cm_length = length of colormap
%
%   This makes size(cm,1)-1 equal sized bins.  The first bin starts on clim(1)
%   and the last bin ends on clim(2).  The bins on each end also include all of
%   the points out of the clim range).  Any data greater than clim(2) is set
%   to clim(2) and any data less than clim(1) is set to clim(1).
a = fix((a-clim(1))./diff(clim).*size(cm,1))+1;

% Clip the image to go from 1 to size of the colormap
a = max(1,min(size(cm,1),a));

% Convert the colormap to 8 bits per color (if not already uint8)
if isa(cm,'double'), cm=uint8(round(cm*255)); end

% Extract r,g,b components
r = uint8(zeros(size(a))); r(:) = cm(a,1);
g = uint8(zeros(size(a))); g(:) = cm(a,2);
b = uint8(zeros(size(a))); b(:) = cm(a,3);

% Combine into single array for output
rgb = cat(ndims(a)+1,r,g,b);

% Modification History:
%
% $Log: scaled2rgb.m,v $
% Revision 1.7  2005/02/03 16:58:36  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.6  2003/10/22 15:54:36  gadde
% Make some CVS info accessible through variables
%
% Revision 1.5  2003/06/16 18:28:14  michelich
% Only issue MEX file warning once.
%
% Revision 1.4  2002/09/30 19:54:13  michelich
% Added ability to pass uint8 colormap to m-file version
%
% Revision 1.3  2002/09/19 01:05:16  michelich
% Added ability to pass uint8 colormap for increased performance.
%
% Revision 1.2  2002/09/09 19:44:31  michelich
% Added warning message if using the m-file version
%
% Revision 1.1  2002/08/28 19:09:05  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2002/04/27. Implemented uint8 version as MEX for better performance
%                                Removed uint16 & double support & changed to single output to match MEX
% Charles Michelich, 2001/10/19. Updated help comments and added error checking
%                                Changed scaling to used standard MATLAB colormap behavior
% Charles Michelich, 2001/09/07. modified for output support of uint8, uint16, double
% Charles Michelich, 2001/09/06. modified for N-D arrays with output of uint8's
% Charles Michelich, 2001/03/14. original. (based on ind2rgb)
