function format=autodetectmr(filenames)
%AUTODETECTMR Attempt to detect the format of an mr file
%
%   format = autodetectmr(filenames);
%
%   If successful, returns the name of the format of the given
%   file(s) (see 'readmr help' for supported data types).
%   Otherwise returns an empty string.  "filenames" can either be a
%   string or a cell array of strings.

% CVS ID and authorship of this code
% CVSId = '$Id: autodetectmr.m,v 1.27 2005/02/03 16:58:37 michelich Exp $';
% CVSRevision = '$Revision: 1.27 $';
% CVSDate = '$Date: 2005/02/03 16:58:37 $';
% CVSRCSFile = '$RCSfile: autodetectmr.m,v $';

lasterr('');
emsg=''; % Initialize error message for catch
try
  format = '';
  
  if ischar(filenames)
    filenames = {filenames};
  end
  
  for i=1:length(filenames)
    if ~isempty(findstr(filenames{i}, '*'))
      dents = dir(filenames{i});
      if isempty(dents),
        emsg=sprintf('No files found matching %s',filenames{i}); error(emsg);
      end
      pathstr = fileparts(filenames{i});
      if ~isempty(pathstr)
        pathstr = [pathstr filesep];
      end
      filenames{i} = strcat(pathstr,dents(1).name);
    end
    fileurl = filename2url(filenames{i});
    proto = get(fileurl, 'Scheme');
    if ~strcmp(proto, 'file')
      emsg=sprintf('Can''t autodetect remote URLs ("%s")!', filenames{i}); error(emsg);
    end
    filenames{i} = get(fileurl, 'Path');
    if strcmp(filesep, '\') & filenames{i}(1) == '/'
      filenames{i} = filenames{i}(2:end);
    end
    if ~exist(filenames{i}, 'file')
      emsg=sprintf('File "%s" doesn''t exist!', filenames{i}); error(emsg);
    end
  end
  
  % 'DICOM_*'
  if isdicom(filenames{1})
    format = 'DICOM';
    return
  end
  
  % open file read-only, with little-endian format
  [fid,emsg] = fopenlocation(filenames{1}, {'r', 'l'});
  if fid==-1, error(emsg); end
  
  % 'AVW_VolumeFile'
  fseek(fid, 0, 'bof');
  magic = fgetl(fid);
  if strncmp(magic,'AVW_VolumeFile',length('AVW_VolumeFile'))
    if size(filenames) > 1
      fclose(fid);
      emsg='It makes no sense to have multiple AVW volume files!'; error(emsg);
    end
    format = 'AVW_VolumeFile';
    fclose(fid);
    return
  end
  
  % 'Signa5'
  fseek(fid, 0, 'bof');
  magic = fread(fid, [1,4], 'char=>char');
  if strcmp(magic, 'IMGF')
    format = 'Signa5';
    fclose(fid);
    return
  end
  
  % 'SignaXIMG'
  status = fseek(fid, 3228, 'bof');
  if status == 0
    magic = fread(fid, [1,4], 'char=>char');
    if strcmp(magic, 'IMGF')
      format = 'SignaXIMG';
      fclose(fid);
      return
    end
  end
  
  % 'Analyze7.5_SPM'
  [path,name,ext,vers] = fileparts(filenames{1});
  if strcmp(ext, '.hdr') | ...
        (strcmp(ext, '.img') & ...
         exist(fullfile(path,[name '.hdr' vers]), 'file') == 2)
    hdrfilename = fullfile(path, [name '.hdr' vers]);
    % make sure we don't open the same file twice...
    fid2 = fid;
    if ~strcmp(ext, '.hdr')
      fid2 = fopenlocation(hdrfilename, {'r', 'l'});
    end
    fseek(fid2, 0, 'bof');
    chars = fread(fid2, 4, 'uint8');
    hdrsizeBigEndian = ((((chars(1) * 256) + chars(2)) * 256) + chars(3)) * 256 + chars(4);
    hdrsizeLittleEndian = ((((chars(4) * 256) + chars(3)) * 256) + chars(2)) * 256 + chars(1);
    d = dir(hdrfilename);
    if ~strcmp(ext, '.hdr')
      fclose(fid2);
    end
    if any(d.bytes == [hdrsizeLittleEndian,hdrsizeBigEndian])
      format = 'Analyze7.5_SPM';
      fclose(fid);
      return
    end
  end
  
  % 'BXH'
  fseek(fid, 0, 'bof');
  % we assume no lines are greater than 8192.  If they are, then we
  % assume it's a binary file.
  while 1
    % find first non-space line
    magic = fgets(fid,8192);
    if magic == -1, break, end
    if isempty(findstr(magic, sprintf('\n'))), break, end
    if all(isspace(magic)), continue, end
    break
  end
  % Find XML magic
  if magic(1) ~= -1 & ~isempty(findstr(magic, sprintf('\n'))) & ~isempty(findstr(magic, '<?xml'))
    while 1
      magic = fgets(fid,8192);
      if magic == -1, break, end
      if isempty(findstr(magic, sprintf('\n'))), break, end
      % Now find BXH magic
      if findstr(magic, 'http://www.biac.duke.edu/bxh')
        format = 'BXH';
        fclose(fid);
        return
      end
    end
  end
  
  fclose(fid);
  
catch
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
% $Log: autodetectmr.m,v $
% Revision 1.27  2005/02/03 16:58:37  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.26  2004/08/09 20:04:57  gadde
% Use 'DICOM' as the returned file type for DICOM files.
%
% Revision 1.25  2004/05/06 14:47:49  gadde
% Replace all uses of strfind with findstr (strfind doesn't exist before
% Matlab 6.1).
%
% Revision 1.24  2004/01/12 20:57:19  gadde
% Allow wildcards.
%
% Revision 1.23  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.22  2003/10/14 14:58:53  gadde
% Name change: geturlfromfile => filename2url
%
% Revision 1.21  2003/06/16 17:33:35  gadde
% Change 'url' variable name to not conflict with classname
%
% Revision 1.20  2003/03/24 23:39:27  michelich
% Support little-endian Analyze7.5 headers.
%
% Revision 1.19  2003/03/24 13:50:24  gadde
% Changed name of XIMG format.
%
% Revision 1.18  2003/03/22 14:49:16  gadde
% Support for Signa E*S*I* format
%
% Revision 1.17  2003/03/20 16:58:22  gadde
% *** empty log message ***
%
% Revision 1.16  2003/03/13 21:13:40  gadde
% Force DICOM_Slice if only one file specified.
%
% Revision 1.15  2003/01/27 18:35:22  gadde
% Fix for older Java (in Matlab 6.1).
%
% Revision 1.14  2003/01/27 18:13:49  gadde
% *** empty log message ***
%
% Revision 1.13  2003/01/22 16:00:15  gadde
% Add necessary fclose()s, and force Analyze data to have .img extension.
%
% Revision 1.12  2003/01/22 15:01:54  gadde
% size => length
%
% Revision 1.11  2003/01/21 21:17:38  gadde
% Make sure we don't try to autodetect URLs.
%
% Revision 1.10  2003/01/15 19:28:37  gadde
% Moved DICOM dataset detection into isdicom().
%
% Revision 1.9  2003/01/15 15:10:02  gadde
% Make sure DICOM group/elems are monotonically increasing.
%
% Revision 1.8  2003/01/13 14:48:43  gadde
% Flag those files that we have detected as DICOM but that MATLAB won't read.
%
% Revision 1.7  2003/01/10 15:32:00  gadde
% Changed logical operators from short-circuit to element-wise
%
% Revision 1.6  2003/01/08 21:46:28  michelich
% Use geturlfromfile instead of geturifromfile
%
% Revision 1.5  2003/01/06 20:58:57  gadde
% Allows for URLs now.
%
% Revision 1.4  2002/12/20 21:35:26  gadde
% Added support for DICOM datasets that don't have DICOM file headers.
% Note, Matlab won't read them using dicomread, etc.
%
% Revision 1.3  2002/12/20 20:16:00  michelich
% Close open files before returning
%
% Revision 1.2  2002/12/20 19:48:03  gadde
% Promote single slices to volume status.
%
% Revision 1.1  2002/12/20 18:37:49  gadde
% First version of autodetector.
%
