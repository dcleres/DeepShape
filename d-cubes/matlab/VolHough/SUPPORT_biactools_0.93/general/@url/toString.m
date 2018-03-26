function val = toString(url)

%TOSTRING - Convert URL to canonical string representation
%   urlstr = toString(urlobj);

% CVSId = '$Id: toString.m,v 1.3 2005/02/03 16:58:37 michelich Exp $';
% CVSRevision = '$Revision: 1.3 $';
% CVSDate = '$Date: 2005/02/03 16:58:37 $';
% CVSRCSFile = '$RCSfile: toString.m,v $';

val = '';

if ischar(url.scheme)
  val = [val url.scheme ':'];
end

if ischar(url.host)
  val = [val '//'];
  if ischar(url.user)
    val = [val url.user '@'];
  end
  val = [val url.host];
  if url.port ~= -1
    val = [val ':' url.port];
  end
end

val = [val url.path];

if ischar(url.query)
  val = [val '?' url.query];
end

if ischar(url.frag)
  val = [val '#' url.frag];
end

% $Log: toString.m,v $
% Revision 1.3  2005/02/03 16:58:37  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.2  2003/10/22 15:54:37  gadde
% Make some CVS info accessible through variables
%
% Revision 1.1  2003/03/20 16:58:22  gadde
% *** empty log message ***
%
