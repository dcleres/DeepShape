clc
clear 
close all

addpath('../VolHough/')  

stl_name = '../../models/pseudo_volvo.stl'
%Plot the original STL mesh:
figure
[stlcoords] = READ_stl(stl_name);
xco = squeeze( stlcoords(:,1,:) )';
yco = squeeze( stlcoords(:,2,:) )';
zco = squeeze( stlcoords(:,3,:) )';
[hpat] = patch(xco,yco,zco,'r');
axis equal

dx = max(xco(:)) -  min(xco(:));
dy = max(yco(:)) -  min(yco(:));
dz = max(zco(:)) -  min(zco(:));
scale = dx+dy+dz;
dx = dx/scale;
dy = dy/scale;
dz = dz/scale;


%Voxelise the STL
grid_size = 100;

grid_size_x = round(dx*grid_size);
grid_size_y = round(dy*grid_size);
grid_size_z = round(dz*grid_size);

[OUTPUTgrid] = VOXELISE(grid_size_x,grid_size_y,grid_size_z,stl_name,'xyz');

%zero pad for visualization & postprocessing
padsize = 6;
VoxelMat = zeros(size(OUTPUTgrid,1)+2*padsize,size(OUTPUTgrid,2)+2*padsize,size(OUTPUTgrid,3)+2*padsize);
VoxelMat(padsize + 1:padsize + size(OUTPUTgrid,1),padsize + 1:padsize + size(OUTPUTgrid,2),padsize + 1:padsize + size(OUTPUTgrid,3)) = OUTPUTgrid;

nhood = ones(5,5,5);
VoxelMat = imclose(VoxelMat,nhood);

%Show the voxelised result:
figure;

[vol_handle, n_corners]=VoxelPlotter(VoxelMat,1.0); 
view(3);
daspect([1,1,1]);
set(gca,'xlim',[0 size(VoxelMat,1)], 'ylim',[0 size(VoxelMat,2)], 'zlim',[0 size(VoxelMat,3)]);
title('Voxelized domain')



%Extract polycube structure

%defaults
fltrLM_R = 3;       % filter radius (minimum 3)

[center_img,cube_img, sphcen]=CubeHough(VoxelMat,fltrLM_R);

figure()
[vol_handle, n_corners]=VoxelPlotter(cube_img,  1.0); 
%visual effects (I recommend using the FigureRotator function from MATLAB
%Centeral
view(3);
daspect([1,1,1]);
axis off
%set(gca,'xlim',[0 size(VoxelMat,1)], 'ylim',[0 size(VoxelMat,2)], 'zlim',[0 size(VoxelMat,3)]);#title('PolyCube structure extracted')


figure()
[vol_handle, n_corners]=VoxelPlotter(center_img,  1.0); 
%visual effects (I recommend using the FigureRotator function from MATLAB
%Centeral
view(3);
daspect([1,1,1]);
set(gca,'xlim',[0 size(VoxelMat,1)], 'ylim',[0 size(VoxelMat,2)], 'zlim',[0 size(VoxelMat,3)]);
title('Corners')
