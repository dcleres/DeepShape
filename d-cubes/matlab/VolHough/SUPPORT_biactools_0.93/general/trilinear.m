%TRILINEAR Trilinear interpolation of 3-D array.
%
%   VI=TRILINEAR(V,XI,YI,ZI);
%   VI=TRILINEAR(X,Y,Z,V,XI,YI,ZI);
%
%   Trilinearly interpolate to find VI, the values of the underlying
%     3-D function V at the points in arrays XI, YI and ZI.
%   XI, YI, and ZI must be 3-D arrays of the same size or vectors.
%     Vector arguments are expanded as if by NDGRID.
%   X, Y, and Z specify the points at which the data V is given.
%     They must be 3-D arrays of the same size or vectors.
%     They must be monotonic, and can be non-uniformly spaced.
%     Vector arguments are expanded as if by NDGRID.
%   Out of range values are returned as NaN in VI.
%
%   VI=TRILINEAR(V,XI,YI,ZI);
%     Assumes X=1:N, Y=1:M, Z=1:P where [M,N,P]=SIZE(V).
%
%   Note: X is the first dimension, Y is the second, and Z is the third.
%         This means TRILINEAR(X,Y,Z,V,XI,YI,ZI);
%         is equivalent to INTERP3(Y,X,Z,V,YI,XI,ZI);
%
%   See also INTERP1, INTERP2, INTERP3, INTERPN, MESHGRID, NDGRID.

% Implemented as a MEX file.
