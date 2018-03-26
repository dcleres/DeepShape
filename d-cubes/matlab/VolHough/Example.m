
% EXAMPLE demonstrates SphericalHough to detect spherical objects from 3D 
% MRI dataset. 
%
% Essential support functions are included for this example. Complete
% support functions can be found at the websites below:
%
% SphericalHough http://www.mathworks.com/matlabcentral/fileexchange/48219 
% ordfilt3 http://www.mathworks.com/matlabcentral/fileexchange/22044
% load_nii http://www.mathworks.com/matlabcentral/fileexchange/8797 
% showsrs2 http://wiki.biac.duke.edu/biac:tools
%
%
% Example 3D MRI image "Data_3D.nii.gz" is from the following article: 
% MRH of age-related nephropathy, Tox Path, 2012 Jul;40(5):764-78
% (http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3515870)
% 
% Supplemental material is also available on CIVMspace: 
% http://www.civm.duhs.duke.edu/lx201107
% 
% LX 10/20/2014

%% perform hough transform
% add paths
addpath(genpath('SUPPORT_NIfTI_20140122'))
addpath(genpath('SUPPORT_biactools_0.93'))

nii=load_nii('Data_3D.nii');     % example image for segmentation
img=nii.img;
%defaults
radrange = [2 7];   % radius range (range 1 to very large)
grdthres = 0.2;     % gradient threshold (range 0-1)
fltrLM_R = 8;       % filter radius (minimum 3)
multirad = 0.5;     % multiple radius detection threshold (range 0.1 1)
obj_cint = 0.1;     % object center intensity threshold (range 0-1)

tic
[center_img,sphere_img,cent,radi]=SphericalHough(img,radrange,grdthres,fltrLM_R,multirad,obj_cint);
toc

%% view overlay
% display center and radius
clc
for ind=1:length(radi)
fprintf('Obj %d - ',ind)
fprintf('cen: %d,%d,%d; ',round(cent(ind,:)))
fprintf('rad: %1g pixels\n',radi(ind))
end

% overlay image
segment_img=img;
segment_img(~sphere_img)=0;     % image with segmented spheres only
overlayCfg0.cmapLim=[0 0.7*max(img(:))];
overlayCfg0.cmap=gray(256);
overlayCfg.cmapLim=[0 0.8*max(segment_img(:))];
overlayCfg.cmap=blupos(256);
overlayCfg.transLim=.5;
overlayCfg2.cmapLim=[0 2];
overlayCfg2.cmap=redpos(256);
overlayCfg2.transLim=1;
showsrs2(img,overlayCfg0,segment_img,overlayCfg,center_img,overlayCfg2)

%% save images
save_nii(make_nii(uint8(center_img)),'Results_centr_img.nii.gz');
save_nii(make_nii(uint8(sphere_img)),'Results_sphere_img.nii.gz');
save_nii(make_nii(segment_img),'Results_segment_img.nii.gz');

