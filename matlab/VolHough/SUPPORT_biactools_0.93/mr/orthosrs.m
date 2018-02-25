function [srs_ax,srs_cor,srs_sag]=orthosrs(srs,slicePlane)
%ORTHOSRS Generate other 2 orthogonal volumes from specified MR volume(s).
%
%   [srs_ax,srs_cor,srs_sag]=ORTHOSRS(srs,slicePlane)
%
%   Input variables:
%   tsv is the image volume(s) (must be have 3 or more dimensions)
%   slicePlane is the slice plane of the input series ('axial','coronal','sagittal').
%     Only the first letter is checked, and case is insignificant.
%
%   Output variables:
%   srs_ax is the specified volume in axial orientation
%   srs_cor is the specified volume in coronal orientation
%   srs_sag is the specified volume in sagittal orientation
%
%   Notes:
%     Volumes are NOT cubed to save memory
%     Supports any number of dimensions >= 3
%     Output NOT written to disk
%
%   Examples:
%   >>[srs_ax,srs_cor,srs_sag]=orthosrs(tsv,'a');
%   >>[srs_ax,srs_cor,srs_sag]=orthosrs(tsv,'cor');

% CVS ID and authorship of this code
% CVSId = '$Id: orthosrs.m,v 1.4 2005/02/03 16:58:40 michelich Exp $';
% CVSRevision = '$Revision: 1.4 $';
% CVSDate = '$Date: 2005/02/03 16:58:40 $';
% CVSRCSFile = '$RCSfile: orthosrs.m,v $';

%TODO: Correct for direction of slice acquisition

% Check arguments and setup defaults
error(nargchk(2,2,nargin));

if ndims(srs) < 3
  error('Input series must be have 3 or more dimensions!');
end

% Generate a vector of the dimensions greater than 3
if ndims(srs) == 3
  extraDims = [];
else
  extraDims = 4:ndims(srs);
end

if upper(slicePlane(1))=='A'
  % Axial: X=Lat, Y=AP, Z=Vert
  srs_ax  = srs;                             % Axial
  if nargout > 1
    srs_cor = permute(srs,[1 3 2 extraDims]);  % Axial->Coronal
  end
  if nargout > 2
    srs_sag = permute(srs,[2 3 1 extraDims]);  % Axial->Sagittal
  end
elseif upper(slicePlane(1))=='C'
  % Coronal: X=Lat, Y=Vert, Z=AP
  srs_ax  = permute(srs,[1 3 2 extraDims]);  % Coronal->Axial
  if nargout > 1
    srs_cor = srs;                             % Coronal
  end
  if nargout > 2
    srs_sag = permute(srs,[3 2 1 extraDims]);  % Coronal->Sagittal
  end
elseif upper(slicePlane(1))=='S'
  % Sagittal: X=AP, Y=Vert, Z=Lat
  srs_ax  = permute(srs,[3 1 2 extraDims]);  % Sagittal->Axial
  if nargout > 1
    srs_cor = permute(srs,[3 2 1 extraDims]);  % Sagittal->Coronal
  end
  if nargout > 2
    srs_sag = srs;                             % Sagittal
  end
else
  error('Unknown slice plane!');
end

% Modification History:
%
% $Log: orthosrs.m,v $
% Revision 1.4  2005/02/03 16:58:40  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.3  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.2  2002/08/27 22:57:58  michelich
% Only calculate output orientations requested (for memory efficiency)
%
% Revision 1.1  2002/08/27 22:24:22  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2002/01/14. Fixed bug in Sagittal to Axial conversion.
% Charles Michelich, 2001/09/13. Original.  Adapted from orthomr to support TSV's & passing variables in memory
%                                Added support for higher number of dimensions
% Charles Michelich, 2001/01/23. Changed function name to lowercase.
%                                Changed cubesrs(), writemr() and readmr() to lowercase.
% Francis Favorini,  1999/09/03.
