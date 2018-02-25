function [params,emsg] = readmrhdr(imgFilename,format)
%READMRHDR Read the format from the header file for an MR image
%
%          params = readmrhdr(imgFilename,format)
%   [params emsg] = readmrhdr(imgFilename,format)
%
%   imgFilename - filename for the image
%   format - a string specifying the format of the file
%   params - a struct with fields for each element in the header
%            Required Fields:
%               format - the same string as format
%               matSz - a vector of the size of the image matrix 
%               hdrSz - length of header (in bytes)
%               pixelType - dataType
%               byteOrder - order of bytes
%               allInOne - If > 1, all slices in one file
%             
%            Optional Fields:
%               voxSz - a vector of the voxel dimensions (mm)
%               description - description {a short string}
%               OTHER fields may exist depending on the header format
%
%   If an error occurs while trying to read the header, params is returned
%   empty and the error messages are stored in emsg.
%
%  Note: Since DICOM files are read using dicomread(), the hdrSz, 
%          pixelType, byteOrder, allInOne return [] for DICOM, 
%          DICOM_Volume, & DICOM_AVW_VolumeFile files.
%
%  Note: For the DICOM_Volume & DICOM_AVW_VolumeFile format, it is assumed
%          that all files have the same parameters.

% CVS ID and authorship of this code
% CVSId = '$Id: readmrhdr.m,v 1.22 2005/05/12 18:52:39 gadde Exp $';
% CVSRevision = '$Revision: 1.22 $';
% CVSDate = '$Date: 2005/05/12 18:52:39 $';
% CVSRCSFile = '$RCSfile: readmrhdr.m,v $';

% TODO: Should I add support for reading header of multiple files at once?
% TODO: Add support for automatically detecting the file type.
% TODO: Implement spm_hread,spm_type,spm_platform for reading headers, or add SPM99 to normal path

% Check arguments
error(nargchk(2,2,nargin));
error(nargchk(0,2,nargout));

if ~ischar(imgFilename) | ~ischar(format)
  error('The filename and format must be strings');
end

emsg='';  % Initialize error message to empty
try
  
  % Handle each format separately
  switch format
    
  case 'Analyze7.5_SPM'
    % Read a Analyze 7.5 file with SPM modifications.
    %
    % Assumptions:
    %  Byte-order of the header is the byte-order of the data.
    %
    % References:
    %  Original Analyze 7.5 specification:
    %    http://www.mayo.edu/bir/PDF/ANALYZE75.pdf
    %  SPM Modifications to the Analyze 7.5 specification:
    %    http://www.mrc-cbu.cam.ac.uk/Imaging/Common/spm_format.shtml
    %    http://www.mrc-cbu.cam.ac.uk/Imaging/Common/analyze_fmt.shtml
   
    params = [];

    % Find the actual header file
    [pathStr,name,ext,vers] = fileparts(imgFilename);
    if strcmp(ext,'.img')
      % User specificed .img file.  Assume header is in .hdr
      hdrFilename = fullfile(pathStr,[name,'.hdr',vers]);
    else
      % Otherwise assume user specified header filename.
      hdrFilename = imgFilename;
    end

    % Check that file exists
    if ~exist(hdrFilename,'file')
      emsg = sprintf('Filename %s does not exist!',hdrFilename); error(emsg);
    end
    
    % Verify that this is indeed an Analyze7.5-type file 
    [fid,msg] = fopenlocation(hdrFilename, {'r', 'l'}); % make sure we don't open the same file twice...
    if fid == -1, emsg = msg; error(emsg); end
    fseek(fid, 0, 'bof');
    chars = fread(fid, 4, 'uint8');
    hdrsizeBigEndian = ((((chars(1) * 256) + chars(2)) * 256) + chars(3)) * 256 + chars(4);
    hdrsizeLittleEndian = ((((chars(4) * 256) + chars(3)) * 256) + chars(2)) * 256 + chars(1);
    if hdrsizeLittleEndian == 348
      params.byteOrder = 'l';
    elseif hdrsizeBigEndian == 348
      % need to open using big-endian byte-order
      fclose(fid);
      [fid,emsg] = fopenlocation(hdrFilename, {'r', 'b'});
      if fid == -1, emsg = msg; error(emsg); end
      params.byteOrder = 'b';
    else
      fclose(fid);
      emsg = sprintf('File %s is not an Analyze7.5_SPM file',hdrFilename); error(emsg);
    end

    % Check if is is a NIFTI-1 file
    isnifti = 0;
    fseek(fid, 344, 'bof');
    magic = fread(fid, 4, 'uchar');
    if all(char(magic(1:3))' == 'ni1') & magic(4) == 0
      ifnifti = 1;
    end
    
    % Setup fixed values in header
    params.format = 'Analyze7.5_SPM';
    params.allInOne = 1;
    params.hdrSz = 0;
    
    % Read matrix size
    fseek(fid, 40, 'bof');
    numdims = fread(fid, 1, 'int16');
    params.matSz =  fread(fid, numdims, 'int16')';
   
    % Strip off singleton dimensions greater than 3
    if numdims >= 4 & all(params.matSz(4:end) == 1)
      numdims = 3;
      params.matSz = params.matSz(1:3);
    end
    
    % Read pixelType
    fseek(fid, 70, 'bof');
    datatype = fread(fid, 1, 'int16');
    switch datatype
      case 1, params.pixelType = 'bit1';
      case 2, params.pixelType = 'uint8';
      case 4, params.pixelType = 'int16';
      case 8, params.pixelType = 'int32';
      case 16, params.pixelType = 'float32';
      case 64, params.pixelType = 'float64';
      case 130, params.pixelType = 'int8';    %SPM
      case 132, params.pixelType = 'uint16';  %SPM
      case 136, params.pixelType = 'uint32';  %SPM
      case 256, params.pixelType = 'int8';    %NIFTI-1
      case 512, params.pixelType = 'uint16';  %NIFTI-1
      case 768, params.pixelType = 'uint32';  %NIFTI-1
      case 1024, params.pixelType = 'int64';  %NIFTI-1
      case 1280, params.pixelType = 'uint64'; %NIFTI-1
      otherwise, fclose(fid); error(['Analyze7.5/SPM/NIFTI-1 datatype ' num2str(datatype) ' not supported']);
    end
    
    % Read voxelSize
    fseek(fid, 76 + 4, 'bof'); % start at pixdim[1]
    params.voxSz = fread(fid, numdims, 'float32')';

    % Read description
    fseek(fid, 148, 'bof');
    params.description = char(fread(fid, 80, 'uchar')');
    % Shorten string to null termination.
    null_i = find(params.description == 0);
    if ~isempty(null_i)
      params.description = params.description(1:null_i(1)-1);
    end
    
    fclose(fid);

  case 'Signa5'
    % Header is at the beginning of the file.
    
    % Open the file (Bigendian, read-only)
    fid = fopen(imgFilename,'r','b');
    
    % Read the "IMGF" image file unique magic number
    magicnum = char(fread(fid,4,'schar'))';
    if ~strcmp(magicnum,'IMGF')
      emsg = sprintf('The header for file %s is not the ''Signa5'' (gemr5x.hdr) format!',imgFilename); error(emsg);
    end
    
    % Read the header size
    hdrSz = fread(fid,1,'int32');  % Header size (in bytes)
    
    % Read image size (in-plane)
    xSz = fread(fid,1,'int32');
    ySz = fread(fid,1,'int32');
    
    % Number of bytes in an uncompressed pixel
    bytesperpixel = fread(fid,1,'int32');
    
    % Translate to pixelType and check for errors
    switch bytesperpixel
    case 1
      emsg = sprintf('One bit pixels in %s not supported!',imgFilename); error(emsg);
    case 8
      pixelType = 'int8';  % Signed 8 bit integer
    case 16
      pixelType = 'int16'; % Signed 16 bit integer
    case 24
      emsg = sprintf('16 bit pixels in %s not supported!',imgFilename); error(emsg);
    otherwise
      emsg = sprintf('Invalid pixel type in %s!',imgFilename); error(emsg);
    end
    
    % Find the number of slices
    fseek(fid,3646,'bof');
    zSz = fread(fid,1,'int32');  % Read se_numimages "Number of Images Existing"
    
    % Place required fields into structure
    params.format = 'Signa5';     % name for file format
    params.matSz = [xSz ySz zSz]; % a vector of the size of the image matrix
    params.hdrSz = hdrSz;         % Header size (in bytes)
    params.allInOne = 0;          % One file per image plane
    params.pixelType = pixelType; % MATLAB data type 
    params.byteOrder = 'b';       % Used bigendian byte order
    
  case 'SignaXIMG'
    % Header is in the middle of the file.
    
    % Open the file (Bigendian, read-only)
    fid = fopen(imgFilename,'r','b');
    
    % Read the "IMGF" image file unique magic number
    fseek(fid, 3228, 'bof');
    magicnum = char(fread(fid,4,'schar'))';
    if ~strcmp(magicnum,'IMGF')
      emsg = sprintf('The header for file %s is not the ''SignaXIMG'' format!',imgFilename); error(emsg);
    end
    
    % Read the header size
    hdrSz = fread(fid,1,'int32');  % Header size (in bytes)
    hdrSz = 8432;
    
    % Read image size (in-plane)
    xSz = fread(fid,1,'int32');
    ySz = fread(fid,1,'int32');
    
    % Number of bytes in an uncompressed pixel
    bytesperpixel = fread(fid,1,'int32');
    
    % Translate to pixelType and check for errors
    switch bytesperpixel
     case 1
      emsg = sprintf('One bit pixels in %s not supported!',imgFilename); error(emsg);
     case 8
      pixelType = 'int8';  % Signed 8 bit integer
     case 16
      pixelType = 'int16'; % Signed 16 bit integer
     case 24
      emsg = sprintf('16 bit pixels in %s not supported!',imgFilename); error(emsg);
     otherwise
      emsg = sprintf('Invalid pixel type in %s!',imgFilename); error(emsg);
    end
    
    % Find the number of slices
    fseek(fid,1368,'bof');
    zSz = fread(fid,1,'int32');  % Read se_numimages "Number of Images Existing"
    
    % Place required fields into structure
    params.format = 'SignaADVWorkstation';     % name for file format
    params.matSz = [xSz ySz zSz]; % a vector of the size of the image matrix
    params.hdrSz = hdrSz;         % Header size (in bytes)
    params.allInOne = 1;          % One file per image plane
    params.pixelType = pixelType; % MATLAB data type 
    params.byteOrder = 'b';       % Used bigendian byte order
    
  case 'DICOM_Slice'
    % Single File DICOM image
    %  ONLY supports, 2D, single-frame, grayscale images, which are entirely opaque and contain no overlays.
    %   (These conditions are enforced by dicomread_slicewithcheck)

    % Read the image using dicomread_slicewithcheck
    %  dicomread is faster than dicominfo
    %  dicomread_slicewithcheck includes all of the necessary type checking
    %  dicomread returns enough information to fill in xSz & ySz (the only required fields)
    srs=dicomread_slicewithcheck(imgFilename);
    
    % Fill in the header fields
    params.format = format;
    params.matSz = [size(srs,1) size(srs,2),1];  % DICOM only supports single slice data per file

    % Return empty for fields not used.
    params.pixelType = [];
    params.byteOrder = [];
    params.hdrSz=[];
    params.allInOne = [];
    
  case 'DICOM_Volume'
    % Contruct a volume from DICOM slices using name2spec

    % Get the series specifier from the name
    srsSpec=name2spec(imgFilename);
    
    % Find the number of slices
    currPath=fileparts(srsSpec);
    d=dir(srsSpec);
    fNames=sort({d.name}');
    if isempty(fNames) | isequal(fNames,{''})
      emsg=sprintf('No files found matching %s!',srsSpec); error(emsg);
    end
    zSz=length(fNames);

    % --- Read the DICOM header of the first file ---
    % --- NOTE: ASSUMES ALL FILES ARE THE SAME ---

    % Get the parameters for first DICOM file
    [params,msg] = readmrhdr(fullfile(currPath,fNames{1}),'DICOM_Slice');
    if ~isempty(msg), emsg = msg; error(emsg); end
    
    % Update the header fields that are different from a standard DICOM file
    params.format = 'DICOM_Volume';
    params.matSz(3) = zSz;    
    
  case 'DICOM_AVW_VolumeFile'
        
    % --- Check that this is a AVW_VolumeFile ---
    % Open file
    if ~exist(imgFilename,'file'), emsg = sprintf('File %s does not exist!',imgFilename); error(emsg); end
    [fid,emsg]=fopen(imgFilename,'r');
    if fid == -1, error(emsg); end
    
    % Check that first line is correct
    uniqueID = fgetl(fid);
    if ~strncmp(uniqueID,'AVW_VolumeFile',length('AVW_VolumeFile'))
      emsg='This is not an Analyze AVW_VolumeFile'; error(emsg);
    end
    
    % --- Count the number of slices ---
    zSz = 0;
    currLine = fgetl(fid); % Read 2nd line
    while isempty(currLine) | (currLine ~= -1)  % isempty is to avoid the [] ~= 1 comparison warning
      % Skip lines starting with #
      if ~isempty(currLine) & currLine(1) ~= '#'
        zSz = zSz +1; % Increment slice counter
        % Save the file name of the first image we encounter.
        if ~exist('firstImageFile','var'), firstImageFile = currLine; end
      end
      % Read next line
      currLine = fgetl(fid);
    end
    fclose(fid); % Close the file
    
    % --- Read the DICOM header of the first file ---
    % --- NOTE: ASSUMES ALL FILES ARE THE SAME ---
    % Get path of AVW_VolumeFile - Interpret all entries in AVW file relative to this path
    basepath=fileparts(imgFilename);
        
    % Get the parameters for this DICOM file
    [params,msg] = readmrhdr(fullfile(basepath,firstImageFile),'DICOM_Slice');
    if ~isempty(msg), emsg = msg; error(emsg); end
    
    % Update the header fields that are different from a standard DICOM file
    params.format = 'DICOM_AVW_VolumeFile';
    params.matSz(3) = zSz;    
    
  otherwise
    % Handle any cases where the header information is not available  
    emsg = sprintf('The function to read the header format for %s has not been implemented',format);
    error(emsg);
  end
  
  % If no errors occured, set emsg to an empty string
  emsg = '';
catch
  % Return an empty array from params
  params = [];
  
  % If the user wants to see the error message, return it to them
  if nargout == 2
    if isempty(emsg)
      if isempty(lasterr)
        emsg='An unidentified error occurred!';
      else
        emsg=lasterr;
      end
    end 
  end
end

% Modification History:
%
% $Log: readmrhdr.m,v $
% Revision 1.22  2005/05/12 18:52:39  gadde
% Update documentation to remove SPM-specific values (which were removed
% in the last revision).
%
% Revision 1.21  2005/05/12 18:39:12  gadde
% Don't read SPM-specific fields (no one uses them).
%
% Revision 1.20  2005/05/11 19:23:08  gadde
% Read all dimensions' origins!
%
% Revision 1.19  2005/02/03 19:18:30  michelich
% Fixed error in error message generation.
%
% Revision 1.18  2005/02/03 16:58:42  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.17  2004/07/29 20:20:00  gadde
% Missed this typo too.
%
% Revision 1.16  2004/07/28 17:22:26  michelich
% Add comment to version 3.0 patched branch.
%
% Revision 1.15  2004/07/28 16:31:58  gadde
% Fix typo and force to three dimensions if dims > 3 are singular.
%
% Revision 1.14  2004/05/04 18:32:59  michelich
% Minor changes for consistency.
%
% Revision 1.13  2004/04/26 19:54:20  gadde
% Whoops, don't erase byteOrder in Analyze7.5_SPM!
%
% Revision 1.12  2004/04/14 23:21:23  michelich
% Analyze7.5_SPM - Close the header file when we are done with it.
%
% Revision 1.11  2004/04/14 23:08:05  michelich
% Analyze7.5_SPM Changes:
%  Issue error if header file not found.
%  Check for error on file open.
%  Corrected hdrSz field (size of header on image, not header file).
%  Read matSz and voxSz with a single read.
%  Make origin a row vector.
%  Shorten description string to null termination.
%
% Revision 1.10  2004/04/14 22:21:05  michelich
% Replace SPM code for reading Analyze7.5_SPM headers with Syam Gadde's clean
% implementation.  Syam implemented this purely from the image file format
% specifications (no SPM code was used or referenced).
%
% Revision 1.9  2003/10/22 15:54:38  gadde
% Make some CVS info accessible through variables
%
% Revision 1.8  2003/07/29 23:41:58  michelich
% Use persistent instead of global variable in Analyze7.5_SPM code.
% Issue an error if header does not exist instead of using global defaults.
%
% Revision 1.7  2003/07/29 20:27:38  gadde
% Determine correct byte order for Analyze.
%
% Revision 1.6  2003/03/24 13:50:41  gadde
% Changed name of XIMG format.
%
% Revision 1.5  2003/03/22 14:49:16  gadde
% Support for Signa E*S*I* format
%
% Revision 1.4  2003/01/30 16:35:49  gadde
% Number of Images Existing (GE series header se_numimages,
% DICOM GEMS:ImagesInSeries) may be more reliable for number
% of slices (slquant is sometimes larger than number of slices).
%
% Revision 1.3  2003/01/08 17:21:47  gadde
% Fixed a minor indentation thing.
%
% Revision 1.2  2002/12/20 18:43:22  gadde
% Allows .hdr or .img to be specified for Analyze files.
% Added GLNX86, removed isieee() check (otherwise errors on
% Red Hat Linux 7.3)
%
% Revision 1.1  2002/08/27 22:24:23  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2002/08/06. Changed help to correctly list name of voxel size field as voxSz.
% Charles Michelich, 2002/04/30. Initialize emsg='' to avoid warnings in error catches & changed an error to use emsg.
% Charles Michelich, 2002/04/29. Changed the name of the DICOM format to DICOM_Slice per Francis's request
%                                Return empty hdrSz, pixelType, byteOrder, startExt, allInOne for 
%                                DICOM, DICOM_Volume, & DICOM_AVW_VolumeFile files.
%                                Changed to use dicomread_slicewithcheck instead of dicominfo to get header info
% Charles Michelich, 2002/04/23. Added reading DICOM, DICOM_Volume, & AVW_VolumeFile(DICOM Only) files.
% Charles Michelich, 2001/01/25. Changed function name to lowercase.
%                                Changed readmr() to lowercase.
% Charles Michelich, 2000/08/07. added supported for Signa5 (gemr5x) header
% Charles Michelich, 2000/04/14. in function spm_type, changed 'float' to 'float32' and 'double' to 'float64'
%	                               to maintain compatibility with readmr pixel types.  Note that the official Analyze
%                                float is 32 bits and double is 64 bits.
% Charles Michelich, 2000/03/27. copied spm_hread,spm_type,and spm_platform to this function
%                                to avoid requiring spm to be installed to use this function
% Charles Michelich, 2000/03/25. original
