%Autho: Itzik Ben Shabat
%Date: 10.5.15
% This scrypt illustrates the use of VoxelPlotter function to visualize
% voxel data stored in a 3d matrix

clear 
close all
clc

%Generating sinthetic input
% how many voxels

% remember 2 does not work for sphere...
eval_size = 20;

% define syntethic domain
sdf = zeros(eval_size,eval_size,eval_size);
sdf(1:10,1:10,1:5) = 1;
sdf(1:4,1:4,6:10) = 1;
% add noise
sdf(10,10,5) = 0;
sdf(7:9,2:4,6) = 1;

sdf(2,3:4,11) = 1;

sdf(4,11,3) = 1;

           

%zero pad for visualization & postprocessing

padsize = 5;
VoxelMat = zeros(size(sdf,1)+2*padsize,size(sdf,2)+2*padsize,size(sdf,3)+2*padsize);
VoxelMat(padsize + 1:padsize + size(sdf,1),padsize + 1:padsize + size(sdf,2),padsize + 1:padsize + size(sdf,3)) = sdf;

% eliminate voxels...
%{
for size = 1:1
    nhood = ones(size,size,size);
    VoxelMat = imopen(VoxelMat,nhood);
end
%}



[vol_handle, n_corners]=VoxelPlotter(VoxelMat,1.0); 
%visual effects (I recommend using the FigureRotator function from MATLAB
%Centeral
view(3);
daspect([1,1,1]);
set(gca,'xlim',[0 size(VoxelMat,1)], 'ylim',[0 size(VoxelMat,2)], 'zlim',[0 size(VoxelMat,3)]);
title('Input binary 3D domain')

n_corners;


%params for hugh circle detection
radrange = [2 4];   % radius range (range 1 to very large)

%defaults
fltrLM_R = 3;       % filter radius (minimum 3)

[center_img,cube_img, sphcen]=CubeHough(VoxelMat,fltrLM_R);

figure()
[vol_handle, n_corners]=VoxelPlotter(cube_img,  1.0); 
%visual effects (I recommend using the FigureRotator function from MATLAB
%Centeral
view(3);
daspect([1,1,1]);
set(gca,'xlim',[0 size(VoxelMat,1)], 'ylim',[0 size(VoxelMat,2)], 'zlim',[0 size(VoxelMat,3)]);
title('PolyCube structure extracted')




%{


%bounding_box =
VoxelMat_visualization=zeros(gridesize+2,gridesize+2,gridesize+2);

VoxelMat=zeros(gridesize,gridesize,gridesize);



for i=1:gridesize
    for j=1:gridesize
        for k=1:gridesize
            if (i-gridesize/2)^2+(j-gridesize/2)^2+(k-gridesize/2)^2<R^2
                VoxelMat(i,j,k)=1;
            end
        end
    end
end
voxel_size = 16/gridesize
VoxelMat_visualization(2:gridesize+1,2:gridesize+1,2:gridesize+1) = VoxelMat;
    
%}