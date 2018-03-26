function tf = eq(u1,u2)
%EQ  == for urls

% CVS ID and authorship of this code
% CVSId = '$Id: eq.m,v 1.5 2005/02/03 17:21:39 michelich Exp $';
% CVSRevision = '$Revision: 1.5 $';
% CVSDate = '$Date: 2005/02/03 17:21:39 $';
% CVSRCSFile = '$RCSfile: eq.m,v $';

tf = logical(0);
if ...
      ((isempty(u1.scheme) & isempty(u2.scheme)) | ...
       strcmp(u1.scheme, u2.scheme)) & ...
      ((isempty(u1.user) & isempty(u2.user)) | ...
       strcmp(u1.user, u2.user)) & ...
      ((isempty(u1.host) & isempty(u2.host)) | ...
       strcmp(u1.host, u2.host)) & ...
      (u1.port == u2.port) & ...
      ((isempty(u1.path) & isempty(u2.path)) | ...
       strcmp(u1.path, u2.path)) & ...
      ((isempty(u1.query) & isempty(u2.query)) | ...
       strcmp(u1.query, u2.query)) & ...
      ((isempty(u1.frag) & isempty(u2.frag)) | ...
       strcmp(u1.frag, u2.frag))
  tf = logical(1);
end

return

% Modification History:
%
% $Log: eq.m,v $
% Revision 1.5  2005/02/03 17:21:39  michelich
% M-lint: Do not use ANS as a variable because ANS is frequently overwritten by MATLAB.
%
% Revision 1.4  2005/02/03 16:58:37  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.3  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.2  2003/08/22 13:19:09  michelich
% Return logical array.  Added CVS ID & history.
%
% Revision 1.1  2003/08/21 19:32:30  gadde
% == for urls