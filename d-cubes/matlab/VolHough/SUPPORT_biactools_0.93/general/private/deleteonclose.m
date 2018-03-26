function handle=deleteonclose(filename, state)
%DELETEONCLOSE - Immediately marks a file for deletion when it is closed.
%
%   deleteonclose(filename);
%
%     NOTE: You should probably use the DELETEONCLOSEACQ and
%           DELETEONCLOSEREL pair of functions unless you are
%           not planning to keep an open reference to the file
%           across the call to this function.
%
%     This function will mark this file for deletion when all current
%     references to it are closed.
%     On UNIX, this is an unlink().
%     On Windows, this would set the FILE_FLAG_CLOSE_ON_DELETE
%     flag (must compile deleteonclose.c).
%     On Windows, this function will probably fail if Matlab already
%     has a file identifier already opened to this file.  Use the
%     pair of functions described in the Note above if possible.
%
%   See Also: DELETEONCLOSEACQ, DELETEONCLOSEREL

% CVS ID and authorship of this code
% CVSId = '$Id: deleteonclose.m,v 1.5 2005/02/03 16:58:37 michelich Exp $';
% CVSRevision = '$Revision: 1.5 $';
% CVSDate = '$Date: 2005/02/03 16:58:37 $';
% CVSRCSFile = '$RCSfile: deleteonclose.m,v $';

if isunix
  % UNIX unlink does what we need
  delete(filename);
else
  % Use DLL for PC implmentation
  error('deleteonclose.c must be compiled for Windows!');
end

% Modification History:
%
% $Log: deleteonclose.m,v $
% Revision 1.5  2005/02/03 16:58:37  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.4  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.3  2003/01/08 17:27:07  gadde
% New method for deleteonclose -- still doesn't work on Windows yet :(
%
% Revision 1.2  2002/10/08 22:53:16  michelich
% Added CVS id & log
% Use MATLAB delete for UNIX
% Error if DLL not here for PC
%
