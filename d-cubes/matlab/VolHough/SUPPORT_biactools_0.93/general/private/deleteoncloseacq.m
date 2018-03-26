function handle=deleteoncloseacq(filename)
%DELETEONCLOSEACQ - Acquire a handle for marking a file "delete on close"
%
%   handle=deleteoncloseacq(filename);
%
%     A common method of using temporary files on UNIX is to get a
%     descriptor (reference) to a file, unlink (delete) the filename
%     from the filesystem space, and continue to access the file
%     through the open file descriptor.  Closing the file descriptor
%     will then really delete the file.
%
%     On Windows, one must open a handle to the file with the
%     appropriate "delete on close" flags set, and then close the
%     handle.  However, if Matlab has the file open already, we can't
%     get a new file handle, because Matlab opens it exclusively.
%     DELETEONCLOSEACQ allows you to open a handle to the file first,
%     i.e. before Matlab would through other means (say, FOPEN).  You
%     may then call DELETEONCLOSEREL on the file handle returned by
%     DELETEONCLOSEACQ to do the equivalent of an unlink().
%
%     To facilitate common code bases, this method is set up to "do
%     the right thing" on both Windows and UNIX systems.
%
%     On UNIX, this function is a no-op and returns the filename.
%     On Windows, this opens the file and returns a file handle string.
%
%     Example of using both functions:
%       handle = deleteoncloseacq(tempfile);
%       fid = fopen(tempfile, 'r');
%       deleteoncloserel(tempfile);
%       ... processing ...
%       fclose(fid); % file should disappear here, assuming no other refs
%
%   See Also: DELETEONCLOSEREL, DELETEONCLOSE

% CVS ID and authorship of this code
% CVSId = '$Id: deleteoncloseacq.m,v 1.3 2005/02/03 16:58:37 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:37 $';
% CVSRCSFile = '$RCSfile: deleteoncloseacq.m,v $';

if isunix
  handle = filename;
else
  handle = deleteonclose(filename, 'acquire');
end

% Modification History:
%
% $Log: deleteoncloseacq.m,v $
% Revision 1.3  2005/02/03 16:58:37  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2003/01/08 17:27:07  gadde
% New method for deleteonclose -- still doesn't work on Windows yet :(
%
