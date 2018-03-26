function [flag,msg]=isdicom(filename)   
% ISDICOM - Check if a file is a DICOM image file
%
%   [flag,emsg]=isdicom(filename)
%      
%        filename - file to check (including path)
%            flag - true if DICOM format, false if not DICOM
%             msg - message if image is not DICOM, empty otherwise
%
% This function works be checking that the first 128 bytes of the
% file is zeros and bytes 129-132 are 'DICM', or that it looks like
% a DICOM dataset in some byte order.
%
% See Also: DICOMREAD, DICOMINFO

% CVS ID and authorship of this code
% CVSId = '$Id: isdicom.m,v 1.7 2005/02/03 16:58:39 michelich Exp $';
% CVSRevision = '$Revision: 1.7 $';
% CVSDate = '$Date: 2005/02/03 16:58:39 $';
% CVSRCSFile = '$RCSfile: isdicom.m,v $';

% Check input arguments
nargchk(1,1,nargin);

% Check that the file exists
if ~exist(filename,'file'), 
  emsg = sprintf('File %s does not exist!',filename); error(emsg);
end

% Open the file for read-only in little-endian byte order
[fid,emsg]=fopen(filename,'r','l');
if fid == -1,
  error(emsg);
  return;
end

% Read the first 132 bytes
[uniqueID,count]=fread(fid,132,'char'); 
fclose(fid);

% Check for the DICOM key
if count == 132 & all((uniqueID'-[zeros(1,128),double('DICM')])==0)
  flag = 1;
  msg = '';
  return
end

% if it is a DICOM file that doesn't have a DICOM file header
% it should still look like DICOM for some byteorder
for byteorder=['l', 'b']
  [fid,emsg] = fopen(filename, 'r', byteorder);
  if fid==-1, error(emsg); end
  try % isolate from file errors
    fseek(fid, 0, 'bof');
    valid = 1;
    status = 0;
    tryelems = 128;
    numelems = 0;
    lastgroup = 0;
    lastelem = 0;
    explicit = -1;
    curpos = 0;
    while curpos ~= -1 & numelems < tryelems
      numelems = numelems + 1;
      group = fread(fid, 1, 'uint16');
      elem = fread(fid, 1, 'uint16');
      % elements must be monotonically increasing!
      if group < lastgroup, valid = 0; break
      elseif group == lastgroup & elem <= lastelem, valid = 0; break
      end
      vr = fread(fid, 2, 'char=>char');
      if explicit == -1
        explicit = (strcmp(upper(vr), vr) & ~strcmp(lower(vr), vr));
      end
      lentype = 'uint16';
      if explicit
        if strcmp(vr, 'OB') | strcmp(vr, 'UN') | ...
              strcmp(vr, 'OW') | strcmp(vr, 'SQ')
          lentype = 'uint32';
          fseek(fid, 2, 'cof');
        end
      else
        lentype = 'uint32';
        fseek(fid, -2, 'cof');
      end
      len = fread(fid, 1, lentype);
      fseek(fid, len, 'cof');
      if feof(fid), break; end
      % disp(sprintf('group=%04x, elem=%04x, len=%d', group, elem, len));
      lastgroup = group;
      lastelem = elem;
      curpos = ftell(fid);
    end
    if valid & ((numelems >= tryelems) | (feof(fid) & numelems > 2))
      flag = 1;
      msg = '';
      fclose(fid);
      return
    end
    fclose(fid);
  catch
    [msg, errnum] = ferror(fid);
    fclose(fid);
    if errnum
      if numelems > 3
	% give benefit of doubt
	flag = 1;
	msg = '';
	return
      end
      % don't care about file errors, do nothing
    else
      error(lasterr);
    end
  end
end

flag = 0;
msg = sprintf('%s is not a DICOM image!',filename);

% Modification History:
%
% $Log: isdicom.m,v $
% Revision 1.7  2005/02/03 16:58:39  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.6  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.5  2003/05/16 16:31:06  gadde
% Fix some logic and close a file descriptor
%
% Revision 1.4  2003/02/03 20:31:11  gadde
% Oops, now DICOM files failed, fix that.
%
% Revision 1.3  2003/01/29 23:09:43  gadde
% Sneaky non-DICOM files could pass DICOM test -- now be more careful.
%
% Revision 1.2  2003/01/15 18:59:58  gadde
% Add check for valid dataset w/o the \0\0\0...\0DICM header.
%
% Revision 1.1  2002/08/27 22:24:21  michelich
% Initial CVS Import
%
%
% Pre CVS History Entries:
% Charles Michelich, 2002-04-23. original
