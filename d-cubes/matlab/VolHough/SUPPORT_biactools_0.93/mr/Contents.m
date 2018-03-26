% BIAC MR Toolbox
% Version 3.0 2004-02-12
% 
% Duke-UNC Brain Imaging and Analysis Center MATLAB Tools for working with
% Magnetic Resonance Imaging data 
% - Requires BIAC General Toolbox
%
% Data display.
%   showsrs     - Display 2D-4D MR image series
%   showsrs2    - Display 2D-4D MR image series with overlays
%   overlay2    - Overlay 1-2 images over another using specified colormaps 
%   mrmontage   - Show montage of MR images.
%   orthoshowsrs -  Load three orthogonal orientations of an image series
%                   into 3 showsrs windows
%   orthooverlay2 - Load three orthogonal orientations of an image and 
%                   overlays into 3 overlay2 windows
%   winlev      - GUI to window and level an image interactively
%
% Data analysis.
%   mrtest      - Run T-Test or Epoch Average on MR series.
%   tstatprofile  - Baseline subtract and calculate statistics on MR
%                   functional data
%   tstatprofile2 - Baseline subtract and calculate statistics on MR
%                   functional data (BXH enabled)
%   qastats2    - Calculate quality assurance statistics on MR study's data.
%   fftmr       - Calculate FFT of each pixel time series in image time
%                 series. 
%   hemoconv    - Convolve hemodynamic function with base function and plot.
%   ksmr        - Calculate Kol(o)mogorov-Smirnov probability that each
%                 pixel time series in deck is normal.
%   mrpolyfit   - Calculate an Nth order polyfit of each time series in the
%                 volume.
%   roistats    - Calculate statistics within ROI for specified MR series.
%   splinealignmr - Temporally align slices within a TR using spline 
%                   interpolation within an image volume
%   splinealigntsv - Temporally align slices within a TR using spline
%                    interpolation in a time series of volumes
%   readparadigm - Read paradigm file
%   findparadigmevents - Parse locations and types of trials from a
%                        paradigm file.
%
% Data I/O.
%   readmr      - Read MR images.
%   readmrhdr   - Read the format from the header file for an MR image.
%   writemr     - Write MR images to file.
%   isdicom     - Check if a file is a DICOM image file.
%   bxhabsorb   - Creates BXH file from input data files and optional format info
%   dmdata2bxh  - Generate BXH file for DMOD file.
%   dicomread_analyzevolumefile - Read DICOM images specified by
%                                 a  AVW_VolumeFile. 
%   dicomread_slicewithcheck - Read a DICOM slice from an image file and 
%                              check its parameters.
%
% Data format functions.
%   autodetectmr - Attempt to detect the format of an mr file
%   convertmrstructtobxh - Take an mr struct and convert what we can to BXH
%   createmrstruct - Create a valid MR struct from a given N-dimensional array
%   datarec2mrinfo - Convert a BXH datarec structure into a MR descriptor
%   mrinfo2datarec - Convert a MR header to a BXH datarec structure
%   readbxhdata - Read data specified by BXH header file.  Intended for
%                 non-image data.  Use readmr for image data.
%   readbxhhdr  - Read BXH header information
%
% ROI tools.
%   isemptyroi  - Returns true for each empty valid ROI in ROIs.
%   isroi       - Returns true for each valid ROI in ROIs.
%   mask2roi    - Convert a BIAC format ROI into a 3D mask.
%   roi2mask    - Convert a 3D mask into a BIAC format ROI.
%   roi2ind     - Convert a BIAC format ROI into linear indicies.
%   roicoords   - Return X,Y,Z coords for specified ROI.
%   roiunion    - Combine one or more ROIs into a single ROI.
%
% Spatial manipulation tools.
%   cropmr      - Crop a run of volume images to a specified size.
%   cropmrexam  - Crop a images in an exam to a specified size.
%   cubesrs     - Pad series with zeros to make a cubic volume.
%   getbounds   - Find the bounding box of an image volume
%   getorientation - Determine orientation of specified image volume.
%   orthomr     - Generate other 2 orthogonal volumes from specified MR
%                 volume and write results to disk.
%   orthosrs    - Generate other 2 orthogonal volumes from specified MR
%                 volume(s). 
%   reorient    - Generate a different orthogonal orientation of specified 
%                 image volume(s).
%   squaresrs   - Pad series with zeros to make images square.
%   transformras - Calculate the permuation and flipdims necessary to 
%                  transform between two RAS flags
%   vol2montage - Generate a montage of slices from a 3D or 4D series
%   vol2time    - Convert a time series of volumes to a slice series of
%                 x,y,t images. 
%   xmr         - Transform image volume using transformation parameters.
%
% Other functions.
%   name2spec   - Convert MR series name to specifier.
%   getzoom     - Get MR series zoom parameters using GUI.
%   iswinlev    - Is the figure a window & level GUI (WINLEV)?
%   iswinlevforfig - Is there a window & level GUI (WINLEV) for this
%                    figure? 

% Support functions (not to be used directly).
%   Used by mrmontage:
%   montagegui
%
%   Used by readmr:
%   readmrgui
%   ras2direction
%
%   Used by overlay2:
%   overlay2_roitool.fig
%   overlay2_roitool.m
%   roicolor
%   roicurrent
%   roidef
%   roifix
%   roifuse
%   roigrow
%   roilimits
%   roilimitsgui
%   roiselect
%   roisort
%   overlaycfggui
%   overlaygui
%
%   Used by showsrs2:
%   showsrs2_cfg
%   showsrs2_cfgtrans
%
%   Used by getzoom:
%   zoomgui
%
%  Deprecated Functions (may be removed in future versions).
%   qastats     - Use qastats2
%   readtsv     - Read MR time series of volumes (TSV) from disk.
%   writetsv    - Write MR time series of volumes (TSV) to disk.
%
%   Used by overlay2, cropmr, and cropmrexam
%   readmrold   - WILL be removed in future versions.  Do not use.
%
% Private functions:
%   private\typespec2str
%

% CVS ID and authorship of this code
% $Id: Contents.m,v 1.15 2005/02/23 02:53:26 michelich Exp $
