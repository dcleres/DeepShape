function [center_img,sphere_img,sphcen,sphrad]=SphericalHoughVoxel(img,radrange,varargin)

% SPHERICALHOUGH detects spherical structures from 3D images. Determines 
% object centers and radii and outputs image mask of centers and spheres.
% This hough transform is based on the gradient field of the image.
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
% EXAMPLE:
% 
% Run Example.m to see demonstration of SphericalHough on 3D MRI data of a
% rat kidney. It demonstrates the detection of kidney glomeruli, which are
% roughly spherical at 31x31x31 um^3 resolution. The expected radii are 
% between 2 to 7 pixels. Example data is from the following article: 
% MRH of age-related nephropathy, Tox Path, 2012 Jul;40(5):764-78
% (http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3515870)
%
% Supplemental material is also available on CIVMspace: 
% http://www.civm.duhs.duke.edu/lx201107
%
% Essential support functions are included for the example. Complete
% support functions can be found at the websites below:
% SphericalHough http://www.mathworks.com/matlabcentral/fileexchange/48219  
% ordfilt3 http://www.mathworks.com/matlabcentral/fileexchange/22044
% load_nii http://www.mathworks.com/matlabcentral/fileexchange/8797 
% showsrs2 http://wiki.biac.duke.edu/biac:tools
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

if numel(radrange) ~= 2 || ~isnumeric(radrange) || radrange(2) - radrange(1) == 0 ,
    error('''radrange'' has to be a two-element vector');
end
prm_r_range = sort(max( [0,0;radrange(1),radrange(2)] ));

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
[~, ExternalVoxels, ~]=FindExternalVoxels(img,1.0);

% Inizialize accumulation matrix
accum = zeros(size(img));

% Initialize voting kernel 
S2 = strel('sphere', radrange(2) );
S1 = strel('sphere', radrange(1) );
K = S2.Neighborhood;

IdxI = ExternalVoxels(:,1);
IdxJ = ExternalVoxels(:,2);
IdxK = ExternalVoxels(:,3);

grdmask_IdxI = ExternalVoxels(:,1);
grdmask_IdxJ = ExternalVoxels(:,2);
grdmask_IdxK = ExternalVoxels(:,3);

%{
for i = 1: size(ExternalVoxels) 
    accum(IdxI(i)-radrange(2):IdxI(i)+radrange(2), IdxJ(i)-radrange(2):IdxJ(i)+radrange(2), IdxK(i)-radrange(2):IdxK(i)+radrange(2)) = ...
    accum(IdxI(i)-radrange(2):IdxI(i)+radrange(2), IdxJ(i)-radrange(2):IdxJ(i)+radrange(2), IdxK(i)-radrange(2):IdxK(i)+radrange(2)) + K;
end
%}
    

% Compute the linear indices (as well as the subscripts) of
% all the votings to the accumulation array.
% A row in matrix 'lin2accum_aJ' contains the J indices (into the
% accumulation array) of all the votings that are introduced by a
% same pixel in the image. Similarly with matrix 'lin2accum_aI'.


rr_4linaccum = double( prm_r_range );
linaccum_dr = [ (-rr_4linaccum(2) + 0.5) : -rr_4linaccum(1) , ...
    (rr_4linaccum(1) + 0.5) : rr_4linaccum(2) ];

lin2accum_aK = floor( ...
	 linaccum_dr + ...    % Compute radius offsets
	repmat( (grdmask_IdxK) , [1,length(linaccum_dr)] ) ...    % Add to base position
);
lin2accum_aJ = floor( ...
	 linaccum_dr + ...    % Compute radius offsets
	repmat( (grdmask_IdxJ) , [1,length(linaccum_dr)] ) ...    % Add to base position
);
lin2accum_aI = floor( ...
	 linaccum_dr + ...
	repmat( (grdmask_IdxI) , [1,length(linaccum_dr)] ) ...
);

% Clip the votings that fall out of intial image grid
mask_valid_aJaIaK = ...
    lin2accum_aK > 0 & lin2accum_aK < (d3 + 1) & ...
	lin2accum_aJ > 0 & lin2accum_aJ < (d2 + 1) & ...
	lin2accum_aI > 0 & lin2accum_aI < (d1 + 1);
mask_valid_aJaIaK_reverse = ~ mask_valid_aJaIaK;
lin2accum_aK = lin2accum_aK .* mask_valid_aJaIaK + mask_valid_aJaIaK_reverse;
lin2accum_aJ = lin2accum_aJ .* mask_valid_aJaIaK + mask_valid_aJaIaK_reverse;
lin2accum_aI = lin2accum_aI .* mask_valid_aJaIaK + mask_valid_aJaIaK_reverse;
clear mask_valid_aJaI_reverse;

% Linear indices (of the votings) into the accumulation array
lin2accum = sub2ind( size(img), lin2accum_aI, lin2accum_aJ, lin2accum_aK);

lin2accum = reshape( lin2accum, [numel(lin2accum),1] );


% Weights of the votings, currently using the gradient maginitudes
% but in fact any scheme can be used (application dependent)

weight4accum = mask_valid_aJaIaK(:);

clear mask_valid_aJaIaK;


% Build the accumulation array using Matlab function 'accumarray'
accum = accumarray( lin2accum , weight4accum );
accum = [ accum ; zeros( numel(img) - numel(accum) , 1 ) ];
accum = reshape( accum, size(img) );


%% locate centers by locating local maximas

loxal_maximas = imregionalmax(accum); %default is 26 connectivity








% -- Filter for searching for local maxima
prm_fltrLM_s = 1.35;
prm_fltrLM_r = ceil( prm_fltrLM_R * 0.6 );
prm_fltrLM_npix = 6; %max([ 6, ceil((prm_fltrLM_R/2)^1.8) ]);

% -- Lower bound of the intensity of local maxima
prm_LM_LoBndRa = 0.2;  % minimum ratio of LM to the max of 'accum'

% Smooth the accumulation array using a 3D Median Filter
disp('Smoothing the Accumulation Array using a 3D Median Filter...');
accum = ordfilt3(accum,'med',3);
disp('Filtration step done.');

% Whole accumulation array as the one AOI=Area Of Interest
accumAOI = [1, size(accum,1), 1, size(accum,2), 1, size(accum,3)];

% Thresholding of 'accum' by a lower bound
prm_LM_LoBnd = max(accum(:)) * prm_LM_LoBndRa;

% Build the filter for searching for local maxima
fltr4LM = zeros(2 * prm_fltrLM_R + 1,...
                2 * prm_fltrLM_R + 1,...
                2 * prm_fltrLM_R + 1);
            
[mesh4fLM_x, mesh4fLM_y, mesh4fLM_z] = ... 
    meshgrid(-prm_fltrLM_R : prm_fltrLM_R,...
             -prm_fltrLM_R : prm_fltrLM_R,...
             -prm_fltrLM_R : prm_fltrLM_R);
         
mesh4fLM_r = sqrt( mesh4fLM_x.^2 + mesh4fLM_y.^2 + mesh4fLM_z.^2);
fltr4LM_mask = ...
	( mesh4fLM_r > prm_fltrLM_r & mesh4fLM_r <= prm_fltrLM_R );
fltr4LM = fltr4LM - ...
	fltr4LM_mask * (prm_fltrLM_s / sum(fltr4LM_mask(:)));

if prm_fltrLM_R >= 4,
	fltr4LM_mask = ( mesh4fLM_r < (prm_fltrLM_r - 1) );
else
	fltr4LM_mask = ( mesh4fLM_r < prm_fltrLM_r );
end
fltr4LM = fltr4LM + fltr4LM_mask / sum(fltr4LM_mask(:));

% For each of the AOIs selected, locate the local maxima
sphcen = zeros(0,3);
for k = 1 : size(accumAOI, 1),
    aoi = accumAOI(k,:);    % just for referencing convenience
    
    % Thresholding of 'accum' by a lower bound
    accumaoi_LBMask = ...
        (accum(aoi(1):aoi(2), aoi(3):aoi(4), aoi(5):aoi(6)) > prm_LM_LoBnd );
    
    % Apply the local maxima filter
    candLM = convn(accum(aoi(1):aoi(2), aoi(3):aoi(4), aoi(5):aoi(6)), ...
        fltr4LM , 'same' );
    candLM_mask = ( candLM > 0 );
    
    % Clear the margins of 'candLM_mask'
    candLM_mask([1:prm_fltrLM_R, (end-prm_fltrLM_R+1):end], :, :) = 0;
    candLM_mask(:, [1:prm_fltrLM_R, (end-prm_fltrLM_R+1):end], :) = 0;
    candLM_mask(:, :, [1:prm_fltrLM_R, (end-prm_fltrLM_R+1):end]) = 0;

    % Group the local maxima candidates by adjacency, compute the
    % centroid position for each group and take that as the center
    % of one sphere detected
    [candLM_label, candLM_nRgn] = bwlabeln( candLM_mask, 26 );

    for ilabel = 1 : candLM_nRgn,
        % Indices (to current AOI) of the pixels in the group
        candgrp_masklin = find( candLM_label == ilabel );
        [candgrp_IdxI, candgrp_IdxJ, candgrp_IdxK] = ...
            ind2sub( size(candLM_label) , candgrp_masklin );

        % Indices (to 'accum') of the pixels in the group
        candgrp_IdxI = candgrp_IdxI + ( aoi(1) - 1 );
        candgrp_IdxJ = candgrp_IdxJ + ( aoi(3) - 1 );
        candgrp_IdxK = candgrp_IdxK + ( aoi(5) - 1 );
        candgrp_idx2acm = ...
            sub2ind(size(accum), candgrp_IdxI, candgrp_IdxJ, candgrp_IdxK);

        % Minimum number of qualified pixels in the group
        if sum(accumaoi_LBMask(candgrp_masklin)) < prm_fltrLM_npix,
            continue;
        end

        % Compute the centroid position
        candgrp_acmsum = sum( accum(candgrp_idx2acm) );
        cc_x = sum( candgrp_IdxJ .* accum(candgrp_idx2acm) ) / ...
            candgrp_acmsum;
        cc_y = sum( candgrp_IdxI .* accum(candgrp_idx2acm) ) / ...
            candgrp_acmsum;
        cc_z = sum( candgrp_IdxK .* accum(candgrp_idx2acm) ) / ...
            candgrp_acmsum;
        sphcen = [sphcen; cc_x, cc_y, cc_z];
    end
end



%% determine radii
% Parameters for the estimation of the radii of spheres
fltr4SgnCv = [2 1 1];
fltr4SgnCv = fltr4SgnCv / sum(fltr4SgnCv);

% Find sphere's radius using its signature curve
sphrad = zeros( size(sphcen,1), 1 );
clear SgnCv2
clear cirrad2 %cirrad2 = zeros( size(circen2) ); 

for k = 1 : size(sphcen,1),
    % Neighborhood region of the sphere for building the sgn. curve
    circen_round = round( sphcen(k,:) );
    SCvR_I0 = circen_round(2) - prm_r_range(2) - 1;
    if SCvR_I0 < 1,
        SCvR_I0 = 1;
    end
    SCvR_I1 = circen_round(2) + prm_r_range(2) + 1;
    if SCvR_I1 > d1,
        SCvR_I1 = d1;
    end
    SCvR_J0 = circen_round(1) - prm_r_range(2) - 1;
    if SCvR_J0 < 1,
        SCvR_J0 = 1;
    end
    SCvR_J1 = circen_round(1) + prm_r_range(2) + 1;
    if SCvR_J1 > d2,
        SCvR_J1 = d2;
    end
    SCvR_K0 = circen_round(3) - prm_r_range(2) - 1;
    if SCvR_K0 < 1,
        SCvR_K0 = 1;
    end
    SCvR_K1 = circen_round(3) + prm_r_range(2) + 1;
    if SCvR_K1 > d3,
        SCvR_K1 = d3;
    end
    
    % Build the sgn. curve
    SgnCvMat_dx = repmat( (SCvR_J0:SCvR_J1) - sphcen(k,1) , ...
        [SCvR_I1 - SCvR_I0 + 1 , 1, SCvR_K1 - SCvR_K0 + 1]);
    SgnCvMat_dy = repmat( (SCvR_I0:SCvR_I1)' - sphcen(k,2) , ...
        [1, SCvR_J1 - SCvR_J0 + 1, SCvR_K1 - SCvR_K0 + 1] );
    temp(1,1,:)=SCvR_K0:SCvR_K1;
    SgnCvMat_dz = repmat( temp - sphcen(k,3) , ...
        [SCvR_I1 - SCvR_I0 + 1, SCvR_J1 - SCvR_J0 + 1, 1] );
    clear temp;
    
    SgnCvMat_r = sqrt( SgnCvMat_dx .^2 + SgnCvMat_dy .^2 + SgnCvMat_dz .^2 );
    SgnCvMat_rp1 = round(SgnCvMat_r) + 1;

    f4SgnCv = abs( ...
        double(img(SCvR_I0:SCvR_I1, SCvR_J0:SCvR_J1, SCvR_K0:SCvR_K1)) .* SgnCvMat_dx + ...
        double(img(SCvR_I0:SCvR_I1, SCvR_J0:SCvR_J1, SCvR_K0:SCvR_K1)) .* SgnCvMat_dy + ...
        double(img(SCvR_I0:SCvR_I1, SCvR_J0:SCvR_J1, SCvR_K0:SCvR_K1)) .* SgnCvMat_dz ...
        ) ./ SgnCvMat_r;
    SgnCv = accumarray( SgnCvMat_rp1(:) , f4SgnCv(:) );

    SgnCv_Cnt = accumarray( SgnCvMat_rp1(:) , ones(numel(f4SgnCv),1) );
    SgnCv_Cnt = SgnCv_Cnt + (SgnCv_Cnt == 0);
    SgnCv = SgnCv ./ SgnCv_Cnt;
    
    % Suppress the undesired entries in the sgn. curve
    % -- Radii that correspond to short arcs
    SgnCv = SgnCv .* ( SgnCv_Cnt >= (pi/4 * [0:(numel(SgnCv_Cnt)-1)]') );
    % -- Radii that are out of the given range
    SgnCv( 1 : (round(prm_r_range(1))+1) ) = 0;
    SgnCv( (round(prm_r_range(2))+1) : end ) = 0;

    % Get rid of the zero radius entry in the array
    SgnCv = SgnCv(2:end);
    % Smooth the sgn. curve
    SgnCv = filtfilt( fltr4SgnCv , [1] , SgnCv );

    % Get the maximum value in the sgn. curve
    SgnCv_max = max(SgnCv);
    if SgnCv_max <= 0,
        sphrad(k) = 0;
        continue;
    end

    % Find the local maxima in sgn. curve by 1st order derivatives
    % -- Mark the ascending edges in the sgn. curve as 1s and
    % -- descending edges as 0s
    SgnCv_AscEdg = ( SgnCv(2:end) - SgnCv(1:(end-1)) ) > 0;
    % -- Mark the transition (ascending to descending) regions
    SgnCv_LMmask = [ 0; 0; SgnCv_AscEdg(1:(end-2)) ] & (~SgnCv_AscEdg);
    SgnCv_LMmask = SgnCv_LMmask & [ SgnCv_LMmask(2:end) ; 0 ];

    % Incorporate the minimum value requirement
    SgnCv_LMmask = SgnCv_LMmask & ...
        ( SgnCv(1:(end-1)) >= (prm_multirad * SgnCv_max) );
    % Get the positions of the peaks
    SgnCv_LMPos = sort( find(SgnCv_LMmask) );

    % Save the detected radii
    if isempty(SgnCv_LMPos),
        sphrad(k) = 0;
    else
        sphrad(k) = SgnCv_LMPos(end);
        for i_radii = (length(SgnCv_LMPos) - 1) : -1 : 1,
            sphrad = [ sphrad; SgnCv_LMPos(i_radii) ];
        end
    end
end

%% Mapping center and radius into image space
tmp=sub2ind([d1,d2,d3],round(sphcen(:,2)),round(sphcen(:,1)),round(sphcen(:,3)));
center_img=false([d1,d2,d3]);
center_img(tmp)=1;

sphere_img=false([d1,d2,d3]);
sphere_img(tmp)=1;
for ind=1:length(sphrad)    % determines sphere from center, rad
    for r=1:sphrad(ind);    % loops from 1 up to radius to create full sphere, not just surface
    phi=linspace(0,pi,30);
    theta=linspace(0,2*pi,40);
    [phi,theta]=meshgrid(phi,theta);
    x=r*sin(phi).*cos(theta);
    y=r*sin(phi).*sin(theta);
    z=r*cos(phi);
    x=x+sphcen(ind,1);
    y=y+sphcen(ind,2);
    z=z+sphcen(ind,3);
    % check if admissible
    y(y>d1)=d1; x(x>d2)=d2; z(z>d3)=d3; 
    y(y<1)=1; x(x<1)=1; z(z<1)=1; 
    tmp=sub2ind([d1,d2,d3],round(y),round(x),round(z));
    sphere_img(tmp)=1;
    end
    end
end

