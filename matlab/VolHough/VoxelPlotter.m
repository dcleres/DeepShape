function [vol_handle, n_corners]=VoxelPlotter(VoxelMat,Vox_Size, color)
%detect the external voxels and faces

if nargin < 3
    color = [0.7,0.7,0.7];

vol_handle=0;
if nargin==1
    Vox_Size=1;
end

[FV,faceColors, ~, n_corners]=FindExternalVoxels(VoxelMat,Vox_Size);
%generate random colors for faces
%faceColors = rand(size(FV.faces,1),1);

%plot only external faces of external voxels
cla;
if size(FV.vertices,1)==0
    cla;
else
    %vol_handle=patch(FV,'FaceColor',color,'EdgeColor',[0.4,0.4,0.4]);
    vol_handle=patch(FV,'FaceVertexCData',faceColors,'FaceColor','flat');
%vol_handle=patch(FV,'FaceColor','r', 'FaceAlpha', alpha);
%use patchslim here for better results
end
end

