function deleteoncloserel(handle)
%DELETEONCLOSEREL - Release a handle used for marking a file "delete on close"
%
%   deleteoncloserel(handle);
%
%     Finish marking a file as "delete on close" by sending this function
%     the return value of DELETEONCLOSEACQ.  See DELETEONCLOSEACQ for
%     detailed help.
%
%     On UNIX, this function is an unlink().
%     On Windows, this function closes the handle.
%
%   See Also: DELETEONCLOSEACQ, DELETEONCLOSE

% CVS ID and authorship of this code
% CVSId = '$Id: deleteoncloserel.m,v 1.3 2005/02/03 16:58:37 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:37 $';
% CVSRCSFile = '$RCSfile: deleteoncloserel.m,v $';

if isunix
  delete(handle);
else
  deleteonclose(handle, 'release');
end

% Modification History:
%
% $Log: deleteoncloserel.m,v $
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
