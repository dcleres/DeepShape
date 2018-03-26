function srs=dicomread_slicewithcheck(fName)
% DICOMREAD_SLICEWITHCHECK - Read a DICOM slice from an image file and check its parameters
%
%   srs=dicomread_slicewithcheck(fName)
%
%           srs - 2D output series
%         fName - name of DICOM file to read (with path if necesssary)
%
%   This function reads a DICOM image from a single image file and checks
%    that it is the following format:
%      2D, single-frame, grayscale, opaque image with no overlays.
% 
%   The image is read using the MATLAB dicomread() function and then the result
%      is checked to make sure that it is the desired format.
%
%   Note: Image returned is cast to a double and transposed to fit with BIAC conventions.
%

% CVS ID and authorship of this code
% CVSId = '$Id: dicomread_slicewithcheck.m,v 1.3 2005/02/03 16:58:38 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:38 $';
% CVSRCSFile = '$RCSfile: dicomread_slicewithcheck.m,v $';

% Single slice DICOM format
%  ONLY supports, 2D, single-frame, grayscale images, which are entirely opaque and contain no overlays.
%   (These conditions are checked for after read).

emsg = '';
try
  % Check that dicominfo exists
  if ~exist('dicomread')
    emsg='Reading DICOM images requires the function dicomread (found in Image Processing Toolbox 3.1 & later)'; error(emsg);
  end
  
  % Check that this image is a DICOM file
  [flag,msg]=isdicom(fName);
  if ~flag, emsg=msg; error(emsg); end
  
  % Read the DICOM file
  [srs, srs_map, srs_alpha, srs_overlays] = dicomread(fName);

  % Make sure that the file is 2D
  %   -This excludes true-color, and multi-frame images
  if ndims(srs) ~= 2
    emsg='DICOM file not grayscale or has mulitple frames.  readmr() currently only supports single-frame grayscale images! Use dicomread!';
    error(emsg);
  end
  
  % Cast result to double because that is what BIAC programs expect.
  % Transpose the image to get orienation that BIAC programs expect.
  srs = double(srs'); 
  
  % Make sure that map is empty
  %  This limits the output to grayscale or truecolor images
  if ~isempty(srs_map)
    emsg='DICOM file has colormap.  readmr() does not support colormaps. Use dicomread!';
    error(emsg);
  end
  
  % Make sure that the whole image is supposed to be opaque
  if any(srs_alpha(:)~=0)
    emsg='DICOM image has an alpha (transparency) channel.  readmr() does not support alpha. Use dicomread!';
    error(emsg);
  end
  
  % Make sure that there are no overlays for the image.
  if ~isempty(srs_overlays)
    emsg='DICOM image has an overlays.  readmr() does not support alpha. Use dicomread!';
    error(emsg);
  end
  
catch
  srs=[];
  if isempty(emsg)
    if isempty(lasterr)
      emsg='An unidentified error occurred!';
    else
      emsg=lasterr;
    end
  end
  error(emsg);
end

% Modification History:
%
% $Log: dicomread_slicewithcheck.m,v $
% Revision 1.3  2005/02/03 16:58:38  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2002/08/27 22:24:20  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2002/04/29. Added check that dicomread() exists
%                                Updated error comments
% Charles Michelich, 2002/04/24. original.
