function [center_img,cube_img, vertices]=CubeHough(img,varargin)

% CUBEHOUGH detects cubical structures from 3D images. Determines 
% object corners and outputs image mask.
%
%
% USAGE:
%
% [center_img,sphere_img,sphcen2,sphrad]=SPHERICALHOUGH(
%    img,radrange,grdthres,fltrLM_R,multirad,obj_cint)
%
%
% USAGE EXAMPLE:
%
% [center_img,sphere_img,sphcen2,sphrad]=SPHERICALHOUGH(
%    img,[2 7],0.4,6,0.5,0.1); User inputs gradient threshold, filter
%    radius, tolerance for multiple radii, obj center intensity threshold.
%
% [center_img,sphere_img,sphcen2,sphrad]=SPHERICALHOUGH(
%    img,[2 7]); Using default values.
%
%
% INPUT: 
%
% img:          3D Binary image
%
% radrange:     The possible minimum and maximum radii of the spheres
%               to be searched, in the format of
%               [minimum_radius, maximum_radius]  (unit: pixels)
%               **NOTE**:  A smaller range saves computational time and
%               memory.
%
%
% fltr4LM_R:    (Optional, default is 8, minimum is 3)
%               The radius of the filter used in the search of local
%               maxima in the accumulation array. To detect spheres whose
%               shapes are less perfect, the radius of the filter needs
%               to be set larger.
%
% multirad:     (Optional, default is 0.5, range is 0.1-1)
%               In case of concentric spheres, multiple radii may be
%               detected corresponding to a single center position. This
%               argument sets the tolerance of picking up the likely
%               radii values. It ranges from 0.1 to 1, where 0.1
%               corresponds to the largest tolerance, meaning more radii
%               values will be detected, and 1 corresponds to the smallest
%               tolerance, in which case only the "principal" radius will
%               be picked up.
%
%
%
% OUTPUT: 
%
% center_img:   Mask image of object centers. Coordinates (x,y,z) are
%               mapped into image space by rounding to the nearest pixel. 
%               This image has the same dimensions as INPUT img.
%
% sphere_img:   Mask image of detected spheres. Spheres are determined from
%               centers and radii and then mapped into image space by
%               rounding to the nearest pixel. This image has the same 
%               dimensions INPUT img.
%
% sphcen:       Center positions of the spheres detected. Is a N-by-3
%               matrix with each row contains the (x, y) positions
%               of a sphere. For concentric spheres (with the same center
%               position), say k of them, the same center position will
%               appear k times in the matrix.
%
% sphrad:       Estimated radii of the spheres detected. Is a N-by-1
%               column vector with a one-to-one correspondance to the
%               output 'circen'. A value 0 for the radius indicates a
%               failed detection of the sphere's radius.
%
%
%
%
% INTERNAL PARAMETERS:
%
% The INPUT arguments are just part of the parameters that are used by
% the sphere detection algorithm implemented here. Variables in the code
% with a prefix 'prm_' in the name are the parameters that control the
% judging criteria and the behavior of the algorithm. Default values for
% these parameters can hardly work for all circumstances. Therefore, at
% occasions, the values of these INTERNAL PARAMETERS (parameters that
% are NOT exposed as input arguments) need to be fine-tuned to make
% the sphere detection work as expected.
%
% 
%   2007_03_07 original Circular Hough Transform by Yao Peng
%   2010_08_25 Spherical Hough Transform by Brian Hulette
%   2014_10_20 simpification, filtration, image mapping, classifiers, and 
%              example by Luke Xie

%% arguments and parameters
% Validation of arguments
if ndims(img) ~= 3 || ~isnumeric(img),
    error('''img'' has to be 3 dimensional');
end


% Parameters (default values)

prm_fltrLM_R = 8;       % filter radius (minimum 3)
prm_multirad = 1.0;     % multiple radius detection threshold (range 0.1-1)


% Validation of arguments

vap_fltr4LM = 1;    % filter for the search of local maxima
if nargin > (1 + vap_fltr4LM),
    if isnumeric(varargin{vap_fltr4LM}) && varargin{vap_fltr4LM}(1) >= 3,
        prm_fltrLM_R = varargin{vap_fltr4LM}(1);
    else
        error('''fltr4LM_R'' has to be larger than or equal to 3');
    end
end

vap_multirad = 2;   % multiple radii tolerance
if nargin > (1 + vap_multirad),
    if isnumeric(varargin{vap_multirad}) && ...
        varargin{vap_multirad}(1) >= 0.1 && ...
        varargin{vap_multirad}(1) <= 1,
    prm_multirad = varargin{vap_multirad}(1);
    else
        error('''multirad'' has to be within the range of 0.1-1');
    end
end


%% accum matrix
% Convert the image to single if it is not of class float (single/double)
if ~(isa(img, 'double') || isa(img, 'single')),
    img = single(img);
end

 % store image dimensions
[d1,d2,d3]=size(img);  

% Get indices of boundary voxels
[~, ~, ExternalVoxels, ~]=FindExternalVoxels(img,1.0);

% Inizialize accumulation matrix
accum = zeros(size(img));

%Declared to ease reading
IdxI = ExternalVoxels(:,1);
IdxJ = ExternalVoxels(:,2);
IdxK = ExternalVoxels(:,3);


% Voting procedure: each boundary voxel shoots 3 ortoghonal planes
for i = 1: size(ExternalVoxels) 
    accum(IdxI(i),:,:) = accum(IdxI(i),:,:) +1;
    accum(:,IdxJ(i),:) = accum(:,IdxJ(i),:)+1;
    accum(:,:,IdxK(i)) = accum(:,:,IdxK(i)) +1;
end

% smooth out voting results    
%accum = ordfilt3(accum,'med',3);

%% locate centers by locating local maximas

loxal_maximas = imregionalmax(accum); %default is 26 connectivity

vertices = zeros(0,3);
% get connected components out of local maxima
[candLM_label, candLM_nRgn] = bwlabeln( loxal_maximas, 26 );


% loop over detected corner region
for ilabel = 1 : candLM_nRgn
    
    % Indices (to current AOI) of the pixels in the group
    candgrp_masklin = find( candLM_label == ilabel );
    
    %TODO: not sure about this
    % Filter out valleys
    
    if numel(candgrp_masklin)> 1
        continue
    end
    
    
    [candgrp_IdxI, candgrp_IdxJ, candgrp_IdxK] = ...
        ind2sub( size(candLM_label) , candgrp_masklin );
    
    % Filter out when gap is below threshold
    prm_maxgap = 2;
    
    neigh_26 =  accum(candgrp_IdxI-1:candgrp_IdxI+1,candgrp_IdxJ-1:candgrp_IdxJ+1,candgrp_IdxK-1:candgrp_IdxK+1);
    neigh_26 (2,2,2) = 0;
    
    if (accum(candgrp_IdxI,candgrp_IdxJ,candgrp_IdxK) - max(neigh_26(:)) < prm_maxgap)
        continue
    end
    

    % Indices (to 'accum') of the pixels in the group

    candgrp_idx2acm = ...
        sub2ind(size(accum), candgrp_IdxI, candgrp_IdxJ, candgrp_IdxK);

    % Minimum number of qualified pixels in the group
    %if sum(accumaoi_LBMask(candgrp_masklin)) < prm_fltrLM_npix,
    %    continue;
    %end

    % Compute the centroid position
    candgrp_acmsum = sum( accum(candgrp_idx2acm) );
    cc_x = sum( candgrp_IdxI .* accum(candgrp_idx2acm) ) / ...
        candgrp_acmsum;
    cc_y = sum( candgrp_IdxJ .* accum(candgrp_idx2acm) ) / ...
        candgrp_acmsum;
    cc_z = sum( candgrp_IdxK .* accum(candgrp_idx2acm) ) / ...
        candgrp_acmsum;
    
    %store vertex position
    vertices = [vertices; round(cc_x), round(cc_y), round(cc_z)];
end


%% Mapping corners to polycube structure
tmp=sub2ind([d1,d2,d3],round(vertices(:,1)),round(vertices(:,2)),round(vertices(:,3)));
center_img=false([d1,d2,d3]);
center_img(tmp)=1;

% assemble cube image
cube_img=false([d1,d2,d3]);

% max distance in pixels
THRESHOLD = 1.0;

for i = 1:size(vertices)
    c_i = vertices(i,:);
    % set to very big threshold
    dx = 1000;
    dy = 1000;    
    dz = 1000;
    
    % look for closest matching vertices
    for j = 1:size(vertices)
        %check only other vertices...
        if i == j
            continue
        end
        c_j = vertices(j,:);
        % case 1: look towards +z direction
        if abs(c_i(1) - c_j(1)) <= THRESHOLD && abs(c_i(2) - c_j(2)) <= THRESHOLD && (c_j(3) - c_i(3))>0  && (c_j(3) - c_i(3))< dz
            dz = c_j(3) - c_i(3);
        % case 2: look towards +y direction
        elseif abs(c_i(1) - c_j(1)) <= THRESHOLD && abs(c_i(3) - c_j(3)) <= THRESHOLD && c_j(2) - c_i(2)>0  && c_j(2) - c_i(2)< dy
            dy = c_j(2) - c_i(2);
        % case 3: look towards +x direction
        elseif abs(c_i(2) - c_j(2)) <= THRESHOLD && abs(c_i(3) - c_j(3)) <= THRESHOLD && c_j(1) - c_i(1)>0  && c_j(1) - c_i(1)< dx
            dx = c_j(1) - c_i(1);
        end
    end
    
    % in the case we haven't found cube matches with 3 corners
    if dx == 1000 || dy == 1000 || dz == 1000
        continue
    end
    
    % TODO: debug this shit
    if c_i(1) + round(dx/2) > d1 || c_i(2) + round(dy/2) > d2 || c_i(3) + round(dz/2) > d3
        continue
    end
    
    
    % make sure cube is admissible: i.e. check that barycenter of cube
    % doesn't belong to empty space
    if img( c_i(1) + round(dx/2), c_i(2) + round(dy/2) , c_i(3) + round(dz/2) ) == 0 
        %continue
    end
   
    % TODO: think about a better way to do this...
    cube = img( c_i(1): c_i(1) + dx, c_i(2) : c_i(2) + dy , c_i(3) : c_i(3) + dz );
    
    if (sum(cube(:))/numel(cube(:))) < 0.7
        continue
    end
 
    % if we found 3 matching corners and cube is valid finally draw cube
    cube_img( c_i(1): c_i(1) + dx, c_i(2) : c_i(2) + dy , c_i(3) : c_i(3) + dz ) = 1;   
end
    

end

